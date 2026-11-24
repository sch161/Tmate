// 궁합 검사 PART 2 음식 사진. 키는 DB 의 match_foods.name. 매핑에 없는 음식은 사진 없이 이름만 보여준다.
// 사진은 모두 위키미디어 공용의 자유 이용 허가 사진을 정사각형으로 자르고 480px 로 줄인 것이다. 작가·라이선스·원본 주소는 docs/image-credits.md 에도 적혀 있다.
// 디자인 대기: 화면 나오면 교체 (디자이너 그림이 나오면 이 파일의 사진을 바꾼다)
import malatang from '../assets/images/match-foods/malatang.jpg';
import mintChoco from '../assets/images/match-foods/mint-choco.jpg';
import hawaiianPizza from '../assets/images/match-foods/hawaiian-pizza.jpg';
import cilantro from '../assets/images/match-foods/cilantro.jpg';
import cucumber from '../assets/images/match-foods/cucumber.jpg';
import eggplant from '../assets/images/match-foods/eggplant.jpg';
import dakbal from '../assets/images/match-foods/dakbal.jpg';
import gopchang from '../assets/images/match-foods/gopchang.jpg';
import seonjiHaejangguk from '../assets/images/match-foods/seonji-haejangguk.jpg';
import beondegi from '../assets/images/match-foods/beondegi.jpg';
import hongeo from '../assets/images/match-foods/hongeo.jpg';
import sannakji from '../assets/images/match-foods/sannakji.jpg';
import durian from '../assets/images/match-foods/durian.jpg';
import kongguksu from '../assets/images/match-foods/kongguksu.jpg';
import naengmyeon from '../assets/images/match-foods/naengmyeon.jpg';
import yukhoe from '../assets/images/match-foods/yukhoe.jpg';
import lambSkewers from '../assets/images/match-foods/lamb-skewers.jpg';
import salmon from '../assets/images/match-foods/salmon.jpg';
import tanghulu from '../assets/images/match-foods/tanghulu.jpg';
import roseTteokbokki from '../assets/images/match-foods/rose-tteokbokki.jpg';
import dubaiChocolate from '../assets/images/match-foods/dubai-chocolate.jpg';

export interface MatchFoodImage {
  src: string;
  /** 작가 이름 (출처 표시용) */
  artist: string;
  /** 라이선스 이름 (예: CC BY-SA 4.0) */
  license: string;
  /** 위키미디어 공용의 원본 파일 페이지 */
  sourceUrl: string;
}

const MATCH_FOOD_IMAGES: Record<string, MatchFoodImage> = {
  '마라탕': { src: malatang, artist: 'N509FZ', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Malatang_from_Hope_Tree_(20220226172344).jpg' },
  '민트초코': { src: mintChoco, artist: 'Mbrickn', license: 'CC BY 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Mint_Chocolate_Chip_Ice_Cream.jpg' },
  '하와이안 피자': { src: hawaiianPizza, artist: 'Elsie Hui', license: 'CC BY 2.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Hawaiian_pizza_image.jpg' },
  '고수': { src: cilantro, artist: 'Kpsudeep', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bunches_of_coriander_leaves.jpg' },
  '오이': { src: cucumber, artist: 'Alabama Extension', license: 'CC0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cucumber_Slices_(Alabama_Extension).jpg' },
  '가지': { src: eggplant, artist: 'Grey Geezer', license: 'CC BY-SA 3.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Aubergine-Varianten.JPG' },
  '닭발': { src: dakbal, artist: 'Richmond Chi', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adidas_-_Chicken_Feet.jpg' },
  '곱창': { src: gopchang, artist: 'donza', license: 'CC BY 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Gopchang_and_yeomtong_2.jpg' },
  '선지해장국': { src: seonjiHaejangguk, artist: 'SJ Yang', license: 'CC BY-SA 2.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Korean_soup-Seonjiguk-02.jpg' },
  '번데기': { src: beondegi, artist: '국립국어원', license: 'CC BY-SA 2.0 kr', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Beondegi_3.jpg' },
  '홍어': { src: hongeo, artist: 'egg (Hong, Yun Seon)', license: 'CC BY 2.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Korean_cuisine-Samhap-01.jpg' },
  '산낙지': { src: sannakji, artist: 'LWY (Flickr)', license: 'CC BY 2.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Korean.cuisine-Sannakji.hoe-01.jpg' },
  '두리안': { src: durian, artist: 'Mangiferamagnifica', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Durio_L13_fruit_open.jpg' },
  '콩국수': { src: kongguksu, artist: 'Hyeonyoung Lee 21', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kong-guksu_made_from_Paju_Jangdan_Beans.jpg' },
  '평양냉면': { src: naengmyeon, artist: 'chomjong', license: 'CC BY 2.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Mul-naengmyeon_3.jpg' },
  '육회': { src: yukhoe, artist: 'revi', license: 'CC BY-SA 2.0 kr', sourceUrl: 'https://commons.wikimedia.org/wiki/File:2020-10-20_%EC%9C%A1%ED%9A%8C.jpeg' },
  '양꼬치': { src: lambSkewers, artist: '대경라이프', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Yang-kkochi_5.jpg' },
  '연어': { src: salmon, artist: 'CNEcija12345', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Salmon_sashimi_slices.jpg' },
  '탕후루': { src: tanghulu, artist: 'Riblet15', license: 'CC BY-SA 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Tanghulu_vendor_-_Tamsui,_Taiwan_(2017).jpg' },
  '로제 떡볶이': { src: roseTteokbokki, artist: '호기로운생활', license: 'CC BY-SA 2.5', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ros%C3%A9_tteokbokki_2.png' },
  '두바이 초콜릿': { src: dubaiChocolate, artist: 'WiseWoman', license: 'CC BY 4.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Dubai-Schokolade-Riegel-Angeschnitten.jpg' },
};

export function getMatchFoodImage(foodName: string): MatchFoodImage | undefined {
  return Object.prototype.hasOwnProperty.call(MATCH_FOOD_IMAGES, foodName) ? MATCH_FOOD_IMAGES[foodName] : undefined;
}
