// 알레르기 정보 상태(allergen_status) 라벨 매핑. 화면 문구는 이 파일 한 곳에서만 관리한다.
// 디자인 대기: Figma 에 없는 임시 문구·스타일
import type { AllergenStatus } from '../api/restaurants';

export interface AllergenStatusInfo {
  label: string;
  /** 정보가 공식 확인되지 않은 상태인지 (estimated/unknown) — 스타일 구분용 */
  unverified: boolean;
}

const STATUS_INFO: Record<AllergenStatus, AllergenStatusInfo> = {
  verified: { label: '공식 표 기준', unverified: false },
  official_extract: { label: '공식 사이트 검색 결과 기준 · 원문 확인 권장', unverified: false },
  estimated: { label: '추정 · 가게 확인 필요', unverified: true },
  unknown: { label: '정보 없음', unverified: true },
};

export function getAllergenStatusInfo(status: AllergenStatus): AllergenStatusInfo {
  return STATUS_INFO[status];
}
