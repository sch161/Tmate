// 맛궁합 영수증 인쇄: 부스 진행자가 노트북(맥북 Chrome)에서 여는 화면.
//   프린터 연결(MXW01, Web Bluetooth) → 방 번호로 팀 선택 → 웹캠 사진 → 영수증 미리보기·인쇄 → 다음 팀
//   ?demo=1 이면 서버 대신 예시 팀·음식(src/utils/match-print-demo.ts)을 쓴다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMatchPairFoods, getMatchPrintPhoto, getMatchPrintQueue, getMatchRoomPairs, markMatchPrinted, type MatchFoodCompare, type MatchPrintRequest, type MatchRoomPair } from '../api/match';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { dataUrlToCanvas } from '../utils/match-photo';
import { DEMO_PAIRS, getDemoPairFoods } from '../utils/match-print-demo';
import { RECEIPT_MAX_CARDS, RECEIPT_PHOTO_ASPECT, renderMatchReceipt, type ReceiptImage } from '../utils/match-receipt';
import { buildResultCards, getMatchTier } from '../utils/match-results';
import { Mxw01Printer, type PrintOptions, type PrinterState } from '../utils/mxw01-printer';
import { MXW01_DEFAULT_INTENSITY, MXW01_TEST_PATTERN_HEIGHT, buildPrintData, buildTestPatternMono, monoToRgba, statusErrorMessage } from '../utils/mxw01-protocol';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const DEMO = new URLSearchParams(window.location.search).get('demo') === '1';
const COUNTDOWN_SECONDS = 3;
const PHOTO_WIDTH = 704; // 촬영해 두는 사진의 가로 (영수증 사진 칸 352점의 2배)
const MAX_LOG_LINES = 500;
const DOTS_PER_CM = 80; // 프린터 해상도 203dpi ≒ 1mm 에 8점

// 사진 밝기 선택지 (match-receipt 의 photoGamma: 1 보다 작으면 밝게, 크면 어둡게)
const PHOTO_GAMMAS = [
  { label: '밝게', gamma: 0.75 },
  { label: '보통', gamma: 1 },
  { label: '어둡게', gamma: 1.3 },
];
let photoGamma = 1;

type Step = 'room' | 'camera' | 'preview';

interface Job {
  code: string;
  pair: MatchRoomPair;
  /** 손님이 폰으로 사진을 올린 요청이면 그 id (인쇄 뒤 완료로 표시한다) */
  requestId?: number;
}

// 손님이 폰으로 올린 사진 대기 목록: 진행자 번호(이 탭에서만 기억)와 새로고침 주기
const PASSCODE_KEY = 'tmate-print-passcode';
const QUEUE_POLL_MS = 5000;
let queueTimer: number | undefined;

const stage = qs<HTMLElement>('#stage');
const statusBox = qs<HTMLElement>('#printer-status');
const statusText = qs<HTMLElement>('#printer-status-text');
const printerMessage = qs<HTMLElement>('#printer-message');
const connectButton = qs<HTMLButtonElement>('#connect');
const connectAnyButton = qs<HTMLButtonElement>('#connect-any');
const testButton = qs<HTMLButtonElement>('#test-print');
const disconnectButton = qs<HTMLButtonElement>('#disconnect');
const intensitySelect = qs<HTMLSelectElement>('#intensity');
const ignoreResponses = qs<HTMLInputElement>('#ignore-responses');
const logList = qs<HTMLElement>('#log-list');
const logCount = qs<HTMLElement>('#log-count');

const message = (e: unknown, fallback: string): string => (e instanceof Error && e.message ? e.message : fallback);

// ---------- 진단 로그 ----------

const logLines: string[] = [];

function addLog(text: string): void {
  const now = new Date();
  const pad = (value: number, length = 2): string => String(value).padStart(length, '0');
  const time = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}.${pad(now.getMilliseconds(), 3)}`;
  const line = `${time}  ${text}`;
  logLines.push(line);
  logList?.append(el('li', { class: 'print-log__line' }, line));
  if (logLines.length > MAX_LOG_LINES) {
    logLines.shift();
    logList?.firstElementChild?.remove();
  }
  if (logCount) logCount.textContent = `${logLines.length}줄`;
  if (logList) logList.scrollTop = logList.scrollHeight;
}

async function copyLog(): Promise<void> {
  try {
    await navigator.clipboard.writeText(logLines.join('\n'));
    showToast('진단 로그를 복사했어요');
  } catch {
    showToast('복사하지 못했어요. 로그를 직접 선택해 복사해주세요');
  }
}

function clearLog(): void {
  logLines.length = 0;
  logList?.replaceChildren();
  if (logCount) logCount.textContent = '0줄';
}

// ---------- 1. 프린터 ----------

const STATE_TEXT: Record<PrinterState, string> = {
  idle: '연결 안 됨',
  connecting: '연결하는 중…',
  connected: '연결됨',
  printing: '인쇄 중…',
  disconnected: '연결이 끊어졌어요',
};

let printerBusy = false; // 연결·테스트 인쇄·영수증 인쇄 중 (버튼 잠금)
let chooseAgain = false; // 다시 연결에 실패했으면 다음에는 기기 선택 창을 연다
let onPrinterChange: (() => void) | null = null; // 인쇄 단계가 프린터 상태에 맞춰 버튼을 바꾸는 데 쓴다

let printerState: PrinterState = 'idle';
let printerName: string | null = null;

const printer = new Mxw01Printer({
  onLog: addLog,
  onState: (state, deviceName) => {
    const wasConnected = printerState === 'connected' || printerState === 'printing';
    printerState = state;
    printerName = deviceName;
    // 쓰다가 끊겼으면(프린터 전원이 꺼짐 등) 이전 안내를 지우고 알려준다
    if (state === 'disconnected' && wasConnected) setPrinterMessage('프린터 연결이 끊어졌어요. 프린터 전원을 확인하고 다시 연결해주세요', true);
    paintPrinter();
  },
});

function canReconnectQuietly(): boolean {
  return printer.canReconnect && !chooseAgain;
}

/** 프린터 상태와 바쁨 표시(printerBusy)에 맞춰 왼쪽 카드의 글자와 버튼을 그린다 */
function paintPrinter(): void {
  const supported = Mxw01Printer.isSupported();
  const connected = printerState === 'connected' || printerState === 'printing';
  if (statusBox) statusBox.dataset.state = printerState;
  if (statusText) statusText.textContent = connected && printerName ? `${STATE_TEXT[printerState]} · ${printerName}` : STATE_TEXT[printerState];
  if (connectButton) {
    connectButton.hidden = connected;
    connectButton.disabled = !supported || printerBusy || printerState === 'connecting';
    connectButton.textContent = canReconnectQuietly() ? '다시 연결' : '프린터 연결';
  }
  if (connectAnyButton) connectAnyButton.disabled = !supported || printerBusy || printerState === 'connecting' || connected;
  if (testButton) testButton.disabled = printerBusy || printerState !== 'connected';
  if (disconnectButton) {
    disconnectButton.hidden = !connected;
    disconnectButton.disabled = printerState === 'printing';
  }
  onPrinterChange?.();
}

function setPrinterMessage(text: string, isError = false): void {
  if (!printerMessage) return;
  printerMessage.textContent = text;
  printerMessage.classList.toggle('is-error', isError);
}

function printOptions(): PrintOptions {
  const intensity = Number(intensitySelect?.value);
  return { intensity: Number.isFinite(intensity) && intensity > 0 ? intensity : MXW01_DEFAULT_INTENSITY, ignoreResponses: ignoreResponses?.checked === true };
}

async function connectPrinter(anyDevice: boolean): Promise<void> {
  if (printerBusy) return;
  printerBusy = true;
  setPrinterMessage('');
  try {
    // 기기 선택 창은 클릭 직후에만 열 수 있어서, 이 함수는 클릭 핸들러에서 바로 부른다
    if (!anyDevice && canReconnectQuietly()) {
      try {
        await printer.reconnect();
      } catch (e) {
        chooseAgain = true;
        throw e;
      }
    } else {
      await printer.connect(anyDevice);
    }
    chooseAgain = false;
  } catch (e) {
    setPrinterMessage(message(e, '프린터에 연결하지 못했어요'), true);
    printerBusy = false;
    paintPrinter();
    return;
  }

  // 연결 확인: 상태를 한 번 물어 알림이 오가는지 본다 (실패해도 연결은 유지한다)
  try {
    const status = await printer.getStatus();
    if (status.ok === false) setPrinterMessage(statusErrorMessage(status.errorCode), true);
    else setPrinterMessage(status.battery !== null ? `프린터가 준비됐어요 (배터리 약 ${status.battery}%)` : '프린터가 준비됐어요');
  } catch (e) {
    addLog(`연결 직후 상태 확인 실패 — ${message(e, '알 수 없는 오류')}`);
    setPrinterMessage('연결은 됐지만 프린터가 상태를 알려주지 않아요. 테스트 인쇄로 확인해주세요', true);
  }
  printerBusy = false;
  paintPrinter();
}

async function testPrint(): Promise<void> {
  if (printerBusy) return;
  printerBusy = true;
  paintPrinter();
  setPrinterMessage('테스트 무늬를 보내는 중…');
  try {
    const result = await printer.print(buildPrintData(buildTestPatternMono(), MXW01_TEST_PATTERN_HEIGHT), printOptions());
    setPrinterMessage(result.completed ? '테스트 인쇄를 마쳤어요. 종이에 무늬가 또렷하게 나왔는지 확인해주세요' : '데이터는 보냈지만 프린터의 완료 신호를 받지 못했어요. 종이가 나왔다면 정상이에요', !result.completed);
  } catch (e) {
    setPrinterMessage(message(e, '테스트 인쇄를 하지 못했어요'), true);
  }
  printerBusy = false;
  paintPrinter();
}

// ---------- 단계 전환 ----------

let stageToken = 0; // 단계가 바뀌면 올라간다. 오래 걸린 비동기 작업이 끝났을 때 아직 같은 단계인지 확인한다
let cameraStream: MediaStream | null = null;
let countdownTimer: number | undefined;

function stopCamera(): void {
  window.clearTimeout(countdownTimer);
  cameraStream?.getTracks().forEach((track) => track.stop());
  cameraStream = null;
}

function enterStep(step: Step): number {
  stageToken += 1;
  stopCamera();
  window.clearInterval(queueTimer);
  onPrinterChange = null;
  for (const item of document.querySelectorAll<HTMLElement>('.print-steps__item')) {
    const current = item.dataset.step === step;
    item.classList.toggle('is-current', current);
    if (current) item.setAttribute('aria-current', 'step');
    else item.removeAttribute('aria-current');
  }
  return stageToken;
}

function pairTitle(pair: MatchRoomPair): HTMLElement {
  return el('p', { class: 'print-pair__names' }, pair.nicknameA, el('span', { class: 'print-pair__heart', 'aria-label': '그리고' }, ' ♥ '), pair.nicknameB);
}

function stageHead(title: string, desc: string): HTMLElement {
  return el('header', { class: 'print-stage__head' }, el('h2', { class: 'print-stage__title' }, title), el('p', { class: 'print-stage__desc text-wrap-ko' }, desc));
}

function secondaryButton(label: string, onClick: () => void): HTMLButtonElement {
  const button = el('button', { class: 'print-button', type: 'button' }, label);
  button.addEventListener('click', onClick);
  return button;
}

// ---------- 2. 팀 선택 ----------

/** 손님이 폰으로 올린 사진 대기 목록. 진행자 번호를 넣으면 5초마다 새로 불러오고, 팀을 누르면 그 사진으로 바로 미리보기로 간다 */
function createPhotoQueue(token: number): HTMLElement {
  const list = el('div', { class: 'print-queue__list' });
  const input = el('input', { class: 'input print-queue__input', type: 'password', inputmode: 'numeric', maxlength: '20', placeholder: '진행자 번호', 'aria-label': '진행자 번호', autocomplete: 'off' });
  const submit = el('button', { class: 'print-button', type: 'submit' }, '확인');
  const form = el('form', { class: 'print-queue__form' }, input, submit);
  let passcode = '';
  try {
    passcode = window.sessionStorage.getItem(PASSCODE_KEY) ?? '';
  } catch {
    // 저장소를 못 쓰면 매번 입력한다
  }
  let lastKey = '';
  let opening = false;

  const open = async (request: MatchPrintRequest): Promise<void> => {
    if (opening) return;
    opening = true;
    try {
      const photo = await getMatchPrintPhoto(passcode, request.requestId);
      if (token !== stageToken) return;
      await showPreview({ code: request.code, pair: request.pair, requestId: request.requestId }, photo ? await dataUrlToCanvas(photo) : null);
    } catch (e) {
      opening = false;
      showToast(message(e, '사진을 불러오지 못했어요'));
    }
  };

  const paint = (requests: MatchPrintRequest[]): void => {
    const key = JSON.stringify(requests);
    if (key === lastKey) return;
    lastKey = key;
    if (requests.length === 0) {
      list.replaceChildren(el('p', { class: 'print-queue__empty text-wrap-ko' }, '아직 올라온 사진이 없어요. 손님이 결과 화면에서 사진을 올리면 여기에 나와요'));
      return;
    }
    list.replaceChildren(
      el(
        'ul',
        { class: 'print-pairs' },
        ...requests.map((request) => {
          const button = el(
            'button',
            { class: request.printed ? 'print-pair is-printed' : 'print-pair', type: 'button' },
            el('span', { class: 'print-pair__text' }, pairTitle(request.pair), el('span', { class: 'print-pair__tier' }, `${request.code}번 방 · ${request.printed ? '인쇄함' : '대기 중'}`)),
            el('span', { class: 'print-pair__score' }, `${request.pair.score}%`),
          );
          button.addEventListener('click', () => void open(request));
          return el('li', {}, button);
        }),
      ),
    );
  };

  const load = async (showErrors: boolean): Promise<void> => {
    try {
      const requests = await getMatchPrintQueue(passcode);
      if (token !== stageToken) return;
      form.hidden = true;
      paint(requests);
    } catch (e) {
      if (token !== stageToken) return;
      // 주기적으로 다시 불러올 때의 일시적인 실패는 다음 주기에 다시 시도한다
      if (!showErrors) return;
      window.clearInterval(queueTimer);
      form.hidden = false;
      lastKey = '';
      list.replaceChildren(el('p', { class: 'print-queue__empty is-error text-wrap-ko', role: 'alert' }, message(e, '대기 목록을 불러오지 못했어요')));
    }
  };

  const startPolling = (): void => {
    window.clearInterval(queueTimer);
    void load(true);
    queueTimer = window.setInterval(() => void load(false), QUEUE_POLL_MS);
  };

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    passcode = input.value.trim();
    if (!passcode) return;
    try {
      window.sessionStorage.setItem(PASSCODE_KEY, passcode);
    } catch {
      // 저장소를 못 쓰면 매번 입력한다
    }
    startPolling();
  });

  if (passcode) startPolling();
  else list.replaceChildren(el('p', { class: 'print-queue__empty text-wrap-ko' }, '진행자 번호를 넣으면 손님이 폰으로 올린 사진이 여기에 나와요'));

  return el('section', { class: 'print-queue' }, el('h3', { class: 'print-queue__title' }, '폰으로 올라온 사진'), form, list);
}

function showRoom(): void {
  if (!stage) return;
  const token = enterStep('room');

  const input = el('input', { class: 'input print-room__input', type: 'text', inputmode: 'numeric', maxlength: '4', placeholder: '방 번호 4자리', 'aria-label': '방 번호 4자리', autocomplete: 'off' });
  const submit = el('button', { class: 'btn-primary print-room__submit', type: 'submit', disabled: true }, '팀 찾기');
  const form = el('form', { class: 'print-room' }, input, submit);
  const results = el('div', { class: 'print-room__results' });

  input.addEventListener('input', () => {
    input.value = input.value.replace(/\D/g, '').slice(0, 4);
    submit.disabled = input.value.length !== 4;
  });

  const load = async (code: string): Promise<void> => {
    renderLoading(results);
    let pairs: MatchRoomPair[];
    try {
      pairs = DEMO ? DEMO_PAIRS : await getMatchRoomPairs(code);
    } catch (e) {
      if (token !== stageToken) return;
      renderError(results, message(e, '방 정보를 불러오지 못했어요'), () => void load(code));
      return;
    }
    if (token !== stageToken) return;
    if (pairs.length === 0) {
      renderEmpty(results, '검사를 마친 두 사람이 아직 없어요', '같은 방의 두 사람이 모두 검사를 끝내면 여기에 나와요');
      return;
    }
    const list = el('ul', { class: 'print-pairs' });
    for (const pair of pairs) {
      const button = el(
        'button',
        { class: 'print-pair', type: 'button' },
        el('span', { class: 'print-pair__text' }, pairTitle(pair), el('span', { class: 'print-pair__tier' }, getMatchTier(pair.score).title)),
        el('span', { class: 'print-pair__score' }, `${pair.score}%`),
      );
      button.addEventListener('click', () => void showCamera({ code, pair }));
      list.append(el('li', {}, button));
    }
    results.replaceChildren(el('p', { class: 'print-room__count' }, `${code}번 방 · ${pairs.length}팀${DEMO ? ' (데모 데이터)' : ''}`), list);
  };

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    if (input.value.length === 4) void load(input.value);
  });

  stage.replaceChildren(
    stageHead('방 번호로 팀 찾기', DEMO ? '데모 데이터예요. 아무 번호 4자리나 넣으면 예시 팀이 나와요' : '손님의 궁합 검사 화면에 보이는 방 번호 4자리를 넣어주세요'),
    ...(DEMO ? [] : [createPhotoQueue(token)]),
    el('h3', { class: 'print-queue__title' }, '방 번호로 직접 찾기'),
    form,
    results,
  );
  if (DEMO) input.focus();
}

// ---------- 3. 사진 ----------

function cameraErrorMessage(error: unknown): string {
  const name = error instanceof Error ? error.name : '';
  if (name === 'NotAllowedError' || name === 'SecurityError') return '카메라 권한이 꺼져 있어요. 주소창의 카메라 아이콘에서 허용한 뒤 다시 시도하거나, 사진 없이 인쇄할 수 있어요';
  if (name === 'NotFoundError' || name === 'OverconstrainedError') return '카메라를 찾지 못했어요. 사진 없이 인쇄할 수 있어요';
  if (name === 'NotReadableError' || name === 'AbortError') return '다른 앱이 카메라를 쓰고 있어요. 그 앱을 닫고 다시 시도해주세요';
  return '카메라를 켜지 못했어요. 사진 없이 인쇄할 수 있어요';
}

/** 지금 보이는 영상의 가운데를 영수증 사진 비율로 잘라 캔버스에 담는다 (화면은 거울처럼 보이지만 사진은 실제 방향이다) */
function captureFrame(video: HTMLVideoElement): HTMLCanvasElement {
  const canvas = el('canvas', { class: 'print-cam__still' });
  canvas.width = PHOTO_WIDTH;
  canvas.height = Math.round(PHOTO_WIDTH / RECEIPT_PHOTO_ASPECT);
  const sourceAspect = video.videoWidth / video.videoHeight;
  const cropWidth = sourceAspect > RECEIPT_PHOTO_ASPECT ? video.videoHeight * RECEIPT_PHOTO_ASPECT : video.videoWidth;
  const cropHeight = sourceAspect > RECEIPT_PHOTO_ASPECT ? video.videoHeight : video.videoWidth / RECEIPT_PHOTO_ASPECT;
  canvas.getContext('2d')?.drawImage(video, (video.videoWidth - cropWidth) / 2, (video.videoHeight - cropHeight) / 2, cropWidth, cropHeight, 0, 0, canvas.width, canvas.height);
  return canvas;
}

async function showCamera(job: Job): Promise<void> {
  if (!stage) return;
  const token = enterStep('camera');

  const video = el('video', { class: 'print-cam__video', autoplay: true, playsinline: true, muted: true });
  video.muted = true;
  const overlay = el('div', { class: 'print-cam__overlay', role: 'status' });
  const frame = el('div', { class: 'print-cam' }, video, overlay);
  const actions = el('div', { class: 'print-stage__actions' });
  let photo: HTMLCanvasElement | null = null;

  const skipButton = secondaryButton('사진 없이 인쇄', () => void showPreview(job, null));
  const backButton = secondaryButton('팀 다시 고르기', showRoom);
  const shootButton = el('button', { class: 'btn-primary', type: 'button', disabled: true }, `촬영하기 (${COUNTDOWN_SECONDS}초 뒤 찰칵)`);
  const useButton = el('button', { class: 'btn-primary', type: 'button' }, '이 사진으로 미리보기');
  const retakeButton = secondaryButton('다시 찍기', () => {
    photo?.remove();
    photo = null;
    video.hidden = false;
    overlay.replaceChildren();
    shootButton.disabled = false;
    showLiveActions();
  });
  useButton.addEventListener('click', () => void showPreview(job, photo));

  function showLiveActions(): void {
    actions.replaceChildren(shootButton, skipButton, backButton);
  }

  function showOverlayMessage(text: string, retry?: () => void): void {
    const box = el('div', { class: 'print-cam__notice text-wrap-ko' }, el('p', {}, text));
    if (retry) box.append(secondaryButton('카메라 다시 켜기', retry));
    overlay.replaceChildren(box);
  }

  const startCamera = async (): Promise<void> => {
    shootButton.disabled = true;
    showOverlayMessage('카메라를 켜는 중…');
    try {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error('getUserMedia 없음');
      const stream = await navigator.mediaDevices.getUserMedia({ video: { width: { ideal: 1280 }, height: { ideal: 960 }, facingMode: 'user' }, audio: false });
      if (token !== stageToken) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }
      cameraStream = stream;
      video.srcObject = stream;
      await video.play();
      if (token !== stageToken) return;
      overlay.replaceChildren();
      shootButton.disabled = false;
    } catch (e) {
      if (token !== stageToken) return;
      addLog(`카메라 오류 — ${e instanceof Error ? `${e.name}: ${e.message}` : String(e)}`);
      frame.classList.add('is-error');
      showOverlayMessage(cameraErrorMessage(e), () => {
        frame.classList.remove('is-error');
        void startCamera();
      });
    }
  };

  shootButton.addEventListener('click', () => {
    shootButton.disabled = true;
    let left = COUNTDOWN_SECONDS;
    const tick = (): void => {
      if (token !== stageToken) return;
      if (left > 0) {
        overlay.replaceChildren(el('span', { class: 'print-cam__count' }, String(left)));
        left -= 1;
        countdownTimer = window.setTimeout(tick, 1000);
        return;
      }
      overlay.replaceChildren();
      if (video.videoWidth === 0) {
        showOverlayMessage('카메라 화면이 아직 준비되지 않았어요. 다시 눌러주세요');
        shootButton.disabled = false;
        return;
      }
      photo = captureFrame(video);
      video.hidden = true;
      frame.prepend(photo);
      actions.replaceChildren(useButton, retakeButton, skipButton);
      useButton.focus();
    };
    tick();
  });

  showLiveActions();
  stage.replaceChildren(stageHead('사진 찍기', '두 사람이 화면 안에 들어오면 촬영을 눌러주세요. 화면에 보이는 범위가 그대로 영수증에 들어가요'), el('div', { class: 'print-stage__pair' }, pairTitle(job.pair), el('span', { class: 'print-pair__score' }, `${job.pair.score}%`)), frame, actions);
  await startCamera();
}

// ---------- 4. 미리보기·인쇄 ----------

async function showPreview(job: Job, photo: HTMLCanvasElement | null): Promise<void> {
  if (!stage) return;
  const token = enterStep('preview');
  renderLoading(stage);

  // 음식 카드는 못 불러와도 인쇄는 할 수 있게 한다 (카드 없이)
  let foods: MatchFoodCompare[] = [];
  let foodsError = '';
  try {
    foods = DEMO ? getDemoPairFoods(job.pair.memberNoA, job.pair.memberNoB) : await getMatchPairFoods(job.code, job.pair.memberNoA, job.pair.memberNoB);
  } catch (e) {
    foodsError = message(e, '음식 결과를 불러오지 못했어요');
  }
  if (token !== stageToken) return;

  const cards = buildResultCards(foods, { me: job.pair.nicknameA, friend: job.pair.nicknameB }).slice(0, RECEIPT_MAX_CARDS);
  const date = new Date();
  const draw = (): Promise<ReceiptImage> => renderMatchReceipt({ nicknameA: job.pair.nicknameA, nicknameB: job.pair.nicknameB, score: job.pair.score, cards, photo, date, photoGamma });
  let receipt: ReceiptImage;
  try {
    receipt = await draw();
  } catch (e) {
    if (token !== stageToken) return;
    renderError(stage, message(e, '영수증을 만들지 못했어요'), () => void showPreview(job, photo));
    return;
  }
  if (token !== stageToken) return;

  // 미리보기는 인쇄에 쓰는 점(mono)을 그대로 그린 것이다
  const paper = el('canvas', { class: 'print-paper__canvas', id: 'receipt-canvas', 'aria-label': '인쇄될 영수증 미리보기' });
  const paintPaper = (): void => {
    paper.width = receipt.width;
    paper.height = receipt.height;
    paper.getContext('2d')?.putImageData(new ImageData(monoToRgba(receipt.mono) as Uint8ClampedArray<ArrayBuffer>, receipt.width, receipt.height), 0, 0);
  };
  paintPaper();

  const printButton = el('button', { class: 'btn-primary', type: 'button', id: 'print-receipt' }, '인쇄');
  const nextButton = secondaryButton('다음 팀', showRoom);
  const retakeButton = secondaryButton(photo ? '다시 찍기' : '사진 찍기', () => void showCamera(job));
  const bar = el('div', { class: 'progress print-preview__progress', role: 'progressbar', 'aria-label': '인쇄 진행률', 'aria-valuemin': '0', 'aria-valuemax': '100', hidden: true });
  const result = el('p', { class: 'print-preview__result text-wrap-ko', role: 'status' });
  let printing = false;
  let printedOnce = false;

  const setResult = (text: string, isError = false): void => {
    result.textContent = text;
    result.classList.toggle('is-error', isError);
  };
  const sync = (): void => {
    const ready = printer.isConnected || printer.canReconnect;
    printButton.disabled = printing || printerBusy || !ready;
    nextButton.disabled = printing;
    retakeButton.disabled = printing;
    brightness.disabled = printing;
    if (!ready && !printing) setResult('왼쪽에서 프린터를 먼저 연결해주세요');
    else if (result.textContent === '왼쪽에서 프린터를 먼저 연결해주세요') setResult('');
  };
  onPrinterChange = sync;

  printButton.addEventListener('click', () => {
    void (async () => {
      if (printing || printerBusy) return;
      printing = true;
      printerBusy = true;
      setPrinterMessage('');
      paintPrinter();
      bar.hidden = false;
      bar.style.setProperty('--value', '0');
      setResult('프린터로 보내는 중…');
      try {
        const outcome = await printer.print(buildPrintData(receipt.mono, receipt.height), {
          ...printOptions(),
          onProgress: (sent, total) => {
            const percent = Math.round((sent / total) * 100);
            bar.style.setProperty('--value', String(percent));
            bar.setAttribute('aria-valuenow', String(percent));
            setResult(sent < total ? `프린터로 보내는 중… ${percent}%` : '인쇄하는 중… 종이가 다 나올 때까지 기다려주세요');
          },
        });
        printedOnce = true;
        // 폰으로 올라온 요청이면 대기 목록에서 인쇄함으로 바꾼다 (실패해도 인쇄 결과에는 영향이 없다)
        if (job.requestId !== undefined) void markMatchPrinted(window.sessionStorage.getItem(PASSCODE_KEY) ?? '', job.requestId).catch(() => undefined);
        setResult(outcome.completed ? '인쇄를 마쳤어요. 영수증을 뜯어 전해주세요' : '데이터는 모두 보냈지만 프린터의 완료 신호를 받지 못했어요. 종이가 다 나왔다면 정상이에요', !outcome.completed);
      } catch (e) {
        setResult(message(e, '인쇄하지 못했어요'), true);
      }
      printing = false;
      printerBusy = false;
      bar.hidden = true;
      printButton.textContent = printedOnce ? '한 번 더 인쇄' : '인쇄';
      paintPrinter();
      if (printedOnce) nextButton.focus();
    })();
  });

  // 사진 밝기: 프린터와 조명에 따라 사진이 너무 어둡거나 밝게 찍히면 바꾼다. 고른 값은 다음 팀에도 그대로 쓴다
  const brightness = el('select', { class: 'print-select', id: 'photo-brightness' }, ...PHOTO_GAMMAS.map((item) => el('option', { value: String(item.gamma), selected: item.gamma === photoGamma }, item.label)));
  brightness.addEventListener('change', () => {
    void (async () => {
      photoGamma = Number(brightness.value) || 1;
      brightness.disabled = true;
      try {
        const next = await draw();
        if (token !== stageToken) return;
        receipt = next;
        paintPaper();
      } catch (e) {
        setResult(message(e, '영수증을 다시 만들지 못했어요'), true);
      }
      brightness.disabled = false;
    })();
  });
  const brightnessField = el('label', { class: 'print-field', hidden: !photo }, el('span', {}, '사진 밝기'), brightness);

  const info = el('ul', { class: 'print-preview__info' }, el('li', {}, `영수증 길이 약 ${(receipt.height / DOTS_PER_CM).toFixed(1)}cm (${receipt.height}줄)`), el('li', {}, photo ? '사진 포함' : '사진 없음'));
  if (foodsError) info.append(el('li', { class: 'is-error' }, `${foodsError} (음식 카드 없이 인쇄돼요)`));
  else if (foods.length === 0) info.append(el('li', {}, '음식 카드 없음'));

  stage.replaceChildren(
    stageHead('미리보기와 인쇄', '아래 그림 그대로 인쇄돼요 (프린터가 찍는 흑백 점으로 바꾼 모습이에요)'),
    el(
      'div',
      { class: 'print-preview' },
      el('div', { class: 'print-paper' }, paper),
      el('div', { class: 'print-preview__panel' }, el('div', { class: 'print-stage__pair' }, pairTitle(job.pair), el('span', { class: 'print-pair__score' }, `${job.pair.score}%`)), info, brightnessField, printButton, bar, result, el('div', { class: 'print-stage__actions' }, retakeButton, nextButton)),
    ),
  );
  sync();
}

// ---------- 시작 ----------

async function start(): Promise<void> {
  if (!(await requireAuth())) return;

  const badge = qs('#demo-badge');
  if (badge) badge.hidden = !DEMO;
  qs<HTMLAnchorElement>('#rank-link')?.setAttribute('href', PATHS.matchRank);

  connectButton?.addEventListener('click', () => void connectPrinter(false));
  connectAnyButton?.addEventListener('click', () => void connectPrinter(true));
  testButton?.addEventListener('click', () => void testPrint());
  disconnectButton?.addEventListener('click', () => printer.disconnect());
  qs('#log-copy')?.addEventListener('click', () => void copyLog());
  qs('#log-clear')?.addEventListener('click', clearLog);
  window.addEventListener('pagehide', stopCamera);

  addLog(`브라우저: ${navigator.userAgent}`);
  addLog(`보안 컨텍스트(https/localhost): ${window.isSecureContext ? '예' : '아니오'} · 데모 데이터: ${DEMO ? '예' : '아니오'}`);
  if (Mxw01Printer.isSupported()) {
    navigator.bluetooth
      ?.getAvailability()
      .then((available) => {
        addLog(`Web Bluetooth 있음 · 블루투스 어댑터 사용 가능: ${available ? '예' : '아니오'}`);
        if (!available) setPrinterMessage('맥북의 블루투스가 꺼져 있는 것 같아요. 블루투스를 켠 뒤 연결해주세요', true);
      })
      .catch(() => addLog('Web Bluetooth 있음 · 어댑터 상태 확인 실패'));
  } else {
    addLog('Web Bluetooth 없음 (navigator.bluetooth 가 없다)');
    const unsupported = qs('#bt-unsupported');
    if (unsupported) unsupported.hidden = false;
  }
  paintPrinter();
  showRoom();
}

void start();
