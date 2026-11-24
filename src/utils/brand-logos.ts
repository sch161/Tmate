// 브랜드 이름 → 로고 그림 매핑은 이 파일 한 곳에서만 관리한다. 키는 DB 의 brands.name 이다.
// 로고는 위키미디어 공용에서 "퍼블릭 도메인(단순한 글자·도형 로고)"으로 올라온 것만 쓴다. 상표권은 각 회사에 있고, 가게를 알아보게 하는 용도로만 쓴다.
// 새 로고를 넣으면 파일·라이선스·원본 주소를 docs/image-credits.md 에 함께 적는다. 로고가 없는 브랜드는 음식 종류 기본 그림이 나온다.
import baskinrobbinsLogo from '../assets/images/brands/baskinrobbins.png';
import cocoichibanyaLogo from '../assets/images/brands/cocoichibanya.png';
import composeLogo from '../assets/images/brands/compose.png';
import dominosLogo from '../assets/images/brands/dominos.png';
import lotteriaLogo from '../assets/images/brands/lotteria.png';
import mcdonaldsLogo from '../assets/images/brands/mcdonalds.png';
import megacoffeeLogo from '../assets/images/brands/megacoffee.png';
import momstouchLogo from '../assets/images/brands/momstouch.png';
import nobrandburgerLogo from '../assets/images/brands/nobrandburger.png';
import parisbaguetteLogo from '../assets/images/brands/parisbaguette.png';
import pizzahutLogo from '../assets/images/brands/pizzahut.png';
import sushiroLogo from '../assets/images/brands/sushiro.png';
import twosomeLogo from '../assets/images/brands/twosome.png';

const BRAND_LOGOS: Record<string, string> = {
  "맥도날드": mcdonaldsLogo,
  "롯데리아": lotteriaLogo,
  "피자헛": pizzahutLogo,
  "투썸플레이스": twosomeLogo,
  "메가MGC커피": megacoffeeLogo,
  "컴포즈커피": composeLogo,
  "파리바게뜨": parisbaguetteLogo,
  "배스킨라빈스": baskinrobbinsLogo,
  "맘스터치": momstouchLogo,
  "도미노피자": dominosLogo,
  "코코이찌방야": cocoichibanyaLogo,
  "스시로": sushiroLogo,
  "노브랜드버거": nobrandburgerLogo,
};

export function getBrandLogo(brandName: string | null | undefined): string | undefined {
  if (!brandName) return undefined;
  return Object.prototype.hasOwnProperty.call(BRAND_LOGOS, brandName) ? BRAND_LOGOS[brandName] : undefined;
}
