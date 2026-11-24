// 브랜드 이름 → 로고 그림 매핑은 이 파일 한 곳에서만 관리한다. 키는 DB 의 brands.name 이다.
// 로고는 두 종류다: (1) 위키미디어 공용의 퍼블릭 도메인 로고(brands/*.png, 아래 import), (2) 프로젝트 주인이 모아 준 로고와 대표 메뉴 사진(brands/logos, brands/photos 의 b01~.webp).
// (2)의 저작권·상표권은 각 회사에 있다. 가게를 알아보게 하는 용도로만 쓰며 출처는 docs/image-credits.md 에 적는다.
// 로고가 없는 브랜드는 음식 종류 기본 그림이 나온다.
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

/** 위키미디어 공용 로고 (퍼블릭 도메인) */
const PUBLIC_LOGOS: Record<string, string> = {
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

/** 브랜드 이름 → 파일 이름(b01~). brands/logos 와 brands/photos 가 같은 이름을 쓴다 */
const BRAND_FILES: Record<string, string> = {
  "가장맛있는족발": 'b01',
  "가츠몽": 'b02',
  "공차": 'b03',
  "교동짬뽕": 'b04',
  "교촌치킨": 'b05',
  "국수나무": 'b06',
  "굽네치킨": 'b07',
  "긴자료코": 'b08',
  "김가네": 'b09',
  "네네치킨": 'b10',
  "노랑통닭": 'b11',
  "니뽕내뽕": 'b12',
  "던킨": 'b13',
  "동경규동": 'b14',
  "동대문엽기떡볶이": 'b15',
  "등촌샤브칼국수": 'b16',
  "땅스부대찌개": 'b17',
  "뚜레쥬르": 'b18',
  "라공방": 'b19',
  "라화쿵부": 'b20',
  "롤링파스타": 'b21',
  "마라공방": 'b22',
  "명륜진사갈비": 'b23',
  "미분당": 'b24',
  "미소야": 'b25',
  "미스사이공": 'b26',
  "미스터피자": 'b27',
  "백소정": 'b28',
  "백채김치찌개": 'b29',
  "버거킹": 'b30',
  "보배반점": 'b31',
  "본도시락": 'b32',
  "본죽": 'b33',
  "봉구스밥버거": 'b34',
  "봉추찜닭": 'b35',
  "빽다방": 'b36',
  "샐러디": 'b37',
  "샹츠마라": 'b38',
  "설빙": 'b39',
  "소림마라": 'b40',
  "스타벅스": 'b41',
  "스파게티스토리": 'b42',
  "신의주찹쌀순대": 'b43',
  "신전떡볶이": 'b44',
  "써브웨이": 'b45',
  "아비꼬": 'b46',
  "아웃백스테이크하우스": 'b47',
  "얌샘김밥": 'b48',
  "역전우동0410": 'b49',
  "우동키노야": 'b50',
  "원할머니보쌈족발": 'b51',
  "유가네닭갈비": 'b52',
  "육쌈냉면": 'b53',
  "육회바른연어": 'b54',
  "은행골": 'b55',
  "이디야커피": 'b56',
  "이삭토스트": 'b57',
  "인생아구찜": 'b58',
  "죠스떡볶이": 'b59',
  "짬뽕지존": 'b60',
  "처갓집양념치킨": 'b61',
  "청년다방": 'b62',
  "춘리마라탕": 'b63',
  "쿠우쿠우": 'b64',
  "큰맘할매순대국": 'b65',
  "탕화쿵푸마라탕": 'b66',
  "파파존스": 'b67',
  "페리카나": 'b68',
  "포메인": 'b69',
  "푸라닭": 'b70',
  "프랭크버거": 'b71',
  "피자스쿨": 'b72',
  "피자알볼로": 'b73',
  "하남돼지집": 'b74',
  "하이디라오": 'b75',
  "한솥도시락": 'b76',
  "홍짜장": 'b77',
  "홍콩반점0410": 'b78',
  "BBQ": 'b79',
  "bhc": 'b80',
};

/** 흰색 글자 로고라 어두운 바탕이 필요한 브랜드 */
const DARK_BACKGROUND_LOGOS = new Set(["포메인", "샹츠마라", "공차", "설빙"]);

const LOGO_FILES = import.meta.glob<string>('../assets/images/brands/logos/*.webp', { eager: true, import: 'default' });
const PHOTO_FILES = import.meta.glob<string>('../assets/images/brands/photos/*.webp', { eager: true, import: 'default' });

function fileOf(files: Record<string, string>, folder: string, brandName: string | null | undefined): string | undefined {
  if (!brandName || !Object.prototype.hasOwnProperty.call(BRAND_FILES, brandName)) return undefined;
  return files[`../assets/images/brands/${folder}/${BRAND_FILES[brandName]}.webp`];
}

export function getBrandLogo(brandName: string | null | undefined): string | undefined {
  if (!brandName) return undefined;
  return fileOf(LOGO_FILES, 'logos', brandName) ?? (Object.prototype.hasOwnProperty.call(PUBLIC_LOGOS, brandName) ? PUBLIC_LOGOS[brandName] : undefined);
}

/** 흰색 글자 로고인지 (어두운 바탕 위에 그려야 보인다) */
export function isDarkBackgroundLogo(brandName: string | null | undefined): boolean {
  return Boolean(brandName) && DARK_BACKGROUND_LOGOS.has(brandName as string);
}

/** 브랜드의 대표 메뉴 사진 (가게 카드·가게 상세의 큰 사진용). 없으면 undefined */
export function getBrandPhoto(brandName: string | null | undefined): string | undefined {
  return fileOf(PHOTO_FILES, 'photos', brandName);
}
