// splitSharedNotice 자체 테스트: node scripts/test-notice.mjs (Node 22.18+ 의 .ts 직접 실행 사용)
import assert from 'node:assert/strict';
import { splitSharedNotice } from '../src/utils/notice.ts';

const cases = [
  ['null', null, []],
  ['빈 문자열', '', []],
  ['롯데리아', '※ 조리기구·조리 기름은 다른 제품과 공유될 수 있습니다 / ※ 지점에 따라 판매하지 않는 제품이 있을 수 있습니다', ['조리기구·조리 기름은 다른 제품과 공유될 수 있습니다']],
  ['맥도날드', '※ 모든 제품은 동일한 조리기구를 사용합니다 /  ※ 알레르기 유발 성분이 교차 접촉될 수 있습니다 / / ※ 지점에 따라 판매하지 않는 제품이 있습니다 / ※ ', ['모든 제품은 동일한 조리기구를 사용합니다', '알레르기 유발 성분이 교차 접촉될 수 있습니다']],
  ['※ 없는 단일', '  조리기구 공유  ', ['조리기구 공유']],
];
for (const [name, input, expected] of cases) {
  assert.deepEqual(splitSharedNotice(input), expected, name);
  console.log(`ok - ${name}`, JSON.stringify(splitSharedNotice(input)));
}
console.log(`${cases.length}/${cases.length} passed`);
