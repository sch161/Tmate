// 마스코트 표정 이미지 매핑은 이 파일 한 곳에서만 관리한다. (src/assets/images/mascot/)
import crying from '../assets/images/mascot/crying.png';
import eating from '../assets/images/mascot/eating.png';
import heart from '../assets/images/mascot/heart.png';
import search from '../assets/images/mascot/search.png';
import shout from '../assets/images/mascot/shout.png';
import standing from '../assets/images/mascot/standing.png';
import thinking from '../assets/images/mascot/thinking.png';
import thumbsUp from '../assets/images/mascot/thumbs-up.png';
import tired from '../assets/images/mascot/tired.png';
import wave from '../assets/images/mascot/wave.png';
import { el } from './dom';

// shout 놀람 / heart 하트 / search 돋보기 / thumbs-up 엄지척 / eating 컵케이크 / standing 기본 / wave 땀 흘리며 손 흔들기 / thinking 물음표 / tired 축 처짐 / crying 울음
const MASCOTS = { shout, heart, search, 'thumbs-up': thumbsUp, eating, standing, wave, thinking, tired, crying } as const;

export type MascotName = keyof typeof MASCOTS;
export type MascotSize = 'sm' | 'md' | 'lg';

/** 마스코트 이미지 주소 (캔버스에 그릴 때 쓴다. 화면에는 createMascot 을 쓴다) */
export function getMascotUrl(name: MascotName): string {
  return MASCOTS[name];
}

/** 장식용 마스코트 이미지. 뜻은 옆의 글자가 전하므로 alt 는 비운다. 크기는 common.css 의 .mascot--{size} */
export function createMascot(name: MascotName, size: MascotSize = 'md'): HTMLImageElement {
  return el('img', { class: `mascot mascot--${size}`, src: MASCOTS[name], alt: '', 'aria-hidden': 'true' });
}
