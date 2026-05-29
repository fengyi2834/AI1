(function() {
  'use strict';

  var SUPPORTED = ['zh-CN', 'en-US', 'ja-JP', 'ko-KR'];
  var DEFAULT = 'zh-CN';
  var STORAGE_KEY = 'yiku_lang';

  var FLAGS = { 'zh-CN': '🇨🇳', 'en-US': '🇺🇸', 'ja-JP': '🇯🇵', 'ko-KR': '🇰🇷' };
  var NAMES = { 'zh-CN': '简体中文', 'en-US': 'English', 'ja-JP': '日本語', 'ko-KR': '한국어' };

  var DICT = {
    'zh-CN': {},
    'en-US': {},
    'ja-JP': {},
    'ko-KR': {}
  };

  /* ================================================================
   *  Translation entries — keyed by meaningful English identifiers
   * ================================================================ */

  /* ── Site / Meta ── */
  add('site.title',                          '广西亿库硅藻板 — 环保防火抗菌板材厂家 | 学校医院酒店工程板材',
                                             'Yiku Diatom Board — Eco-Friendly Fireproof Antibacterial Panels',
                                             '億库硅藻板 — 環保・防火・抗菌パネルメーカー',
                                             '이쿠 규조토 보드 — 친환경 방염 항균 패널');

  /* ── Topbar ── */
  add('topbar.phone',                        '招商热线：0779-8525688 / 18169771178',
                                             'Sales: 0779-8525688 / 18169771178',
                                             'お問い合わせ：0779-8525688 / 18169771178',
                                             '문의전화: 0779-8525688 / 18169771178');
  add('topbar.address',                      '广西北海海洋研究创新园科研一路 B1-1 栋',
                                             'Bldg B1-1, Keyan 1st Rd, Marine Research Innovation Park, Beihai, Guangxi',
                                             '広西北海海洋研究イノベーションパーク科研一路 B1-1幢4',
                                             '광시 북해 해양연구혁신단지 과연일로 B1-1동');

  /* ── Brand ── */
  add('brand.name',                          '亿库硅藻板',
                                             'Yiku Diatom Board',
                                             '億库硅藻板',
                                             '이쿠 규조토 보드');
  add('brand.tagline',                       '环保功能型板材方案',
                                             'Eco-Friendly Functional Panel Solutions',
                                             '環保機能型パネルソリューション',
                                             '친환경 기능성 패널 솔루션');

  /* ── Navigation ── */
  add('nav.home',                            '首页',       'Home',               'ホーム',        '홈');
  add('nav.products',                        '产品中心', 'Products',      '製品情報',   '제품정보');
  add('nav.solutions',                       '应用场景', 'Solutions',     '活用事例',   '적용분야');
  add('nav.about',                           '公司介绍', 'About Us',      '会社概要',   '회사소개');
  add('nav.contact',                         '联系我们', 'Contact Us',    'お問い合わせ', '문의하기');
  add('nav.get_plan',                        '获取方案', 'Get a Plan',    'プランを見る', '견적받기');

  /* ── Chat Widget ── */
  add('chat.title',                          '亿库 AI 客服',
                                             'Yiku AI Assistant',
                                             '億库 AIアシスタント',
                                             '이쿠 AI 상담');
  add('chat.subtitle',                       '产品、场景、规格、报价与销售对接',
                                             'Products, applications, specs, pricing & sales',
                                             '製品・活用事例・仕様・お見積もり・営業へのご案内',
                                             '제품·적용분야·규격·견적·영업 연계');
  add('chat.login',                          '登录',       'Login',              'ログイン',   '로그인');
  add('chat.logged_in',                      '已登录', 'Logged In',         'ログイン済み', '로그인됨');
  add('chat.online_chat',                    '在线咨询', 'Online Chat', 'オンライン相談', '온라인상담');
  add('chat.close_chat',                     '关闭咨询', 'Close Chat',  '相談を閉じる', '상담닫기');
  add('chat.placeholder',                    '请输入你的问题', 'Type your question...', '質問を入力してください', '질문을 입력하세요');
  add('chat.send',                           '发送',       'Send',              '送信',              '보내기');
  add('chat.sending',                        '发送中', 'Sending...',        '送信中',         '보내는 중');
  add('chat.locked',                         '已锁定', 'Locked',           'ロック済み', '잠김');
  add('chat.welcome',                        '你好，我是亿库 AI 客服。可以咨询产品适用场景、规格、报价方式和销售联系方式。',
                                             'Hello, I\'m Yiku AI assistant. I can help with product applications, specifications, pricing, and sales contact information.',
                                             'こんにちは、億库AIアシスタントです。製品の活用事例、仕様、お見積もり方法、営業へのお問い合わせについてお答えいたします。',
                                             '안녕하세요, 이쿠 AI 상담원입니다. 제품 적용분야, 규격, 견적 방법, 그리고 영업 연락처에 대해 안내해 드립니다.');
  add('chat.no_reply',                       '暂时没有获取到回复。',
                                             'No response received.',
                                             '現在返事を受け取れませんでした。',
                                             '일시적으로 응답을 받을 수 없습니다.');
  add('chat.network_error',                  '网络异常，请稍后重试。',
                                             'Network error. Please try again later.',
                                             'ネットワークエラー。少し後に再試行してください。',
                                             '네트워크 오류가 발생했습니다. 다시 시도해 주세요.');
  add('chat.service_unavailable',            '当前咨询服务暂时不可用，请稍后再试或直接拨打 0779-8525688。',
                                             'Chat service is currently unavailable. Please try again later or call 0779-8525688.',
                                             '現在チャットサービスをご利用いただけません。少し後に再試行いただくか、お電話 0779-8525688 までご連絡ください。',
                                             '현재 상담 서비스를 이용할 수 없습니다. 다시 시도하거나 0779-8525688로 전화하세요.');
  add('chat.free_used',                      '免费咨询次数已用完',
                                             'Free consultation limit reached',
                                             '無料相談回数が上限に達しました',
                                             '무료 상담 횟수를 초과했습니다');
  add('chat.please_login',                   '请登录后继续咨询',
                                             'Please log in to continue',
                                             'ログインして続けてください',
                                             '로그인하여 계속하세요');
  add('chat.login_register',                 '登录 / 注册',
                                             'Login / Register',
                                             'ログイン / 登録',
                                             '로그인 / 회원가입');
  add('chat.logout_confirm',                 '确定要退出登录吗？',
                                             'Are you sure you want to log out?',
                                             'ログアウトしますか？',
                                             '로그아웃 하시겠습니?');
  add('chat.image_sent',                     '发送了一张图片',
                                             'Sent an image',
                                             '画像を送信しました',
                                             '이미지를 보냈습니다');
  add('chat.remove_image',                   '移除图片',
                                             'Remove image',
                                             '画像を削除',
                                             '이미지 제거');
  add('chat.send_image',                     '发送图片',
                                             'Send image',
                                             '画像を送信',
                                             '이미지 보내기');
  add('chat.handoff',                        '如需报价或人工跟进，请拨打 0779-8525688 / 18169771178，或留下您的联系方式。',
                                             'For pricing or personal assistance, please call 0779-8525688 / 18169771178 or leave your contact information.',
                                             'お見積もりやお問い合わせは、お電話 0779-8525688 / 18169771178 まで、またはご連絡先をお知らせください。',
                                             '견적이나 상담이 필요하시면 0779-8525688 / 18169771178로 전화하거나 연락처를 남겨주세요.');

  /* ── Quick Questions ── */
  add('quick.scenarios',                     '你们产品适合哪些场景？',
                                             'What scenarios are your products suitable for?',
                                             'あなたの製品はどのようなシーンに適しますか？',
                                             '제품이 어떤 용도에 적합한가요?');
  add('quick.school_hospital',               '学校医院能不能用？',
                                             'Can they be used in schools and hospitals?',
                                             '学校や病院で使えますか？',
                                             '학교와 병원에서도 사용 가능한가요?');
  add('quick.specs',                         '规格有哪些？',
                                             'What specifications are available?',
                                             '仕様にはどのようなものがありますか？',
                                             '어떤 규격이 있나요?');
  add('quick.pricing',                       '怎么报价？',
                                             'How is pricing determined?',
                                             'お見積もりはどのように行われますか？',
                                             '견적은 어떻게 진행되나요?');
  add('quick.contact_sales',                 '如何联系销售？',
                                             'How to contact sales?',
                                             '営業へのお問い合わせ方法は？',
                                             '영업팀에게 연락하려면?');
  add('quick.scenarios_short',               '适用场景', 'Applications', '活用事例', '적용분야');
  add('quick.school_hospital_short',         '学校/医院', 'Schools/Hospitals', '学校・病院', '학교/병원');
  add('quick.specs_short',                   '产品规格', 'Specifications', '製品仕様', '제품 규격');
  add('quick.pricing_short',                 '如何报价', 'Pricing', 'お見積もり方法', '견적 방법');
  add('quick.contact_sales_short',           '联系销售', 'Contact Sales', '営業へのお問い合わせ', '영업 문의');

  /* ── Mobile ── */
  add('mobile.menu',                         '菜单',       'Menu',              'メニュー',   '메뉴');
  add('mobile.open_menu',                    '打开菜单', 'Open menu',   'メニューを開く', '메뉴 열기');
  add('mobile.close_menu',                   '关闭菜单', 'Close menu', 'メニューを閉じる', '메뉴 닫기');
  add('mobile.goto_top',                     '回到顶部', 'Back to top', 'トップへ戻る', '맨 위로');

  /* ── Hero ── */
  add('hero.heading',                        '亿库硅藻板',
                                             'Yiku Diatom Board',
                                             '億库硅藻板',
                                             '이쿠 규조토 보드');
  add('hero.text',                           '面向家装、工装、学校、医院、酒店与滨海环境，提供兼顾环保、耐用、防水、阻燃与抗菌能力的功能型板材方案。',
                                             'Functional panel solutions combining eco-friendliness, durability, waterproofing, fire resistance and antibacterial performance for residential, commercial, school, hospital, hotel and coastal environments.',
                                             '住宅・商業施設・学校・病院・ホテル・海岸環境向けに、環保・耐久・防水・防火・抗菌性能を備えた機能型パネルソリューションを提供します。',
                                             '주거용, 상업용, 학교, 병원, 호텔, 및 해안 환경에 적합한 친환경, 내구성, 방수, 방염, 항균 기능을 갖춘 패널 솔루션을 제공합니다.');
  add('hero.cta',                            '获取方案', 'Get a Plan',  'プランを見る', '견적받기');
  add('hero.view_products',                  '查看产品中心', 'View Products', '製品を見る', '제품 보기');
  add('hero.metric1_title',                  '家装 / 工装 / 公共空间',
                                             'Residential / Commercial / Public',
                                             '住宅 / 商業 / 公共空間',
                                             '주거용 / 상업용 / 공공시설');
  add('hero.metric1_desc',                   '典型服务方向',
                                             'Typical Service Areas',
                                             '主なサービス領域',
                                             '주요 서비스 분야');
  add('hero.metric2_title',                  '环保 / 抗菌 / 防水 / 阻燃',
                                             'Eco / Antibacterial / Waterproof / Fireproof',
                                             '環保 / 抗菌 / 防水 / 防火',
                                             '친환경 / 항균 / 방수 / 방염');
  add('hero.metric2_desc',                   '核心能力',
                                             'Core Capabilities',
                                             'コア機能',
                                             '핵심 기능');
  add('hero.metric3_title',                  '规格匹配 / 样品验证 / 报价交付',
                                             'Spec Matching / Sample / Quote & Delivery',
                                             '仕様マッチング / サンプル確認 / お見積もり・納品',
                                             '규격 매칭 / 샘플 검증 / 견적 및 납품');
  add('hero.metric3_desc',                   '项目支持',
                                             'Project Support',
                                             'プロジェクトサポート',
                                             '프로젝트 지원');

  /* ── Why YIKU ── */
  add('why.heading',                         '围绕室内环境与长期耐用性构建产品能力',
                                             'Building product capabilities around indoor environments and long-term durability',
                                             '室内環境と長期的な耐久性を中心にした製品力',
                                             '실내 환경과 장기 내구성을 위한 제품 역량');
  add('why.desc',                            '不把板材只当作装饰层，而是把环保、抗菌、防霉、防水、阻燃和耐腐蚀能力一起放进材料方案里。',
                                             'We don\'t treat panels as just a decorative layer. Instead, we integrate eco-friendliness, antibacterial, anti-mold, waterproof, fireproof, and corrosion resistance into one material solution.',
                                             'パネルを単なる装飾材としてではなく、環保・抗菌・防カビ・防水・防火・耐食性を一つの材料ソリューションに統合します。',
                                             '패널을 단순한 데코 재료가 아닌, 친환경, 항균, 방수, 방염, 부식 방지를 통합한 소재 솔루션으로 제공합니다.');

  add('why.health',                          '环保健康', 'Eco & Healthy', '環保と健康', '친환경&건강');
  add('why.health_desc',                     '产品自身甲醛和重金属未检出，适合对空气质量更敏感的住宅、学校和医疗类空间。',
                                             'No detectable formaldehyde or heavy metals. Ideal for residential, educational, and medical spaces sensitive to air quality.',
                                             'ホルムアルデヒドや重金属が検出されないため、空気質に敏感な住宅、学校、医療施設に最適です。',
                                             '포름알데히드와 중금속이 검출되지 않아 공기질에 민감한 주거용, 학교, 의료용 공간에 적합합니다.');
  add('why.antimicrobial',                   '抗菌防霉', 'Antibacterial & Anti-Mold', '抗菌・防カビ', '항균&방곰파이');
  add('why.antimicrobial_desc',              '可作为医院、学校、实验室等对卫生要求更高场景的材料方向，减少潮湿霉变困扰。',
                                             'Suitable for hospitals, schools, and laboratories with higher hygiene requirements, reducing damp-related mold issues.',
                                             '衛生要求の高い病院、学校、研究施設などに適し、湿気によるカビの問題を軽減します。',
                                             '위생 요구가 높은 병원, 학교, 연구실 등에 적합하며 습기로 인한 곰파이 문제를 줄여줍니다.');
  add('why.fireproof',                       '防水阻燃', 'Waterproof & Fireproof', '防水・防火', '방수&방염');
  add('why.fireproof_desc',                  '具备防水与 B1 级防火能力，适合潮湿环境和对防火有要求的工程空间。',
                                             'Features waterproof performance and B1-level fire resistance. Ideal for humid environments and projects requiring fire safety.',
                                             '防水性とB1クラスの防火性能を備え、湿気の多い環境や防火要求のある工事空間に適します。',
                                             '방수 성능과 B1급 방염 성능을 갖추고 있어 습윤 환경과 방염이 필요한 공간에 적합합니다.');
  add('why.durable',                         '耐腐蚀耐用', 'Corrosion Resistant & Durable', '耐食・耐久', '부식&내구성');
  add('why.durable_desc',                    '耐酸碱、耐腐蚀、不易变形，更适合滨海、船舶和高湿环境的长期应用。',
                                             'Acid/alkali resistant, corrosion resistant, and deformation resistant. Ideal for long-term use in coastal, marine, and high-humidity environments.',
                                             '耐酸・耐アルカリ、耐食、変形しにくく、海岸部、船舶、高湿環境での長期使用に最適です。',
                                             '산/알칼리 저항, 부식 방지, 변형 방지로 해안, 선박, 고습도 환경에서 장기 사용이 가능합니다.');

  /* ── About ── */
  add('about.heading',                       '关于亿库', 'About Yiku',  '億库について', '이쿠에 대하여');
  add('about.desc',                          '广西亿库光养硅藻环保科技有限公司专注环保功能型板材，围绕住宅、学校、医院、酒店、商业空间与滨海项目提供材料解决方案。',
                                             'Guangxi Yiku Guangyang Diatom Environmental Technology Co., Ltd. specializes in eco-friendly functional panels, providing material solutions for residential, educational, medical, hotel, commercial, and coastal projects.',
                                             '広西億库光養硅藻環保科技有限公司は、環保機能型パネルを専門とし、住宅・学校・病院・ホテル・商業施設・海岸プロジェクト向けの素材ソリューションを提供します。',
                                             '광시 이쿠 광양 규조토 환경보호 과학기술 유한회사는 친환경 기능성 패널을 전문으로 하며 주거용, 학교, 병원, 호텔, 상업용 공간, 해안 프로젝트를 위한 자재 솔루션을 제공합니다.');

  add('about.service',                       '服务方式', 'Service Model', 'サービス体制', '서비스 방식');
  add('about.service_desc',                  '需求沟通、规格匹配、样品验证、报价交付与安装售后支持。',
                                             'Requirements consultation, specification matching, sample verification, quotation, delivery, and after-sales installation support.',
                                             '要件のヒアリング、仕様マッチング、サンプル確認、お見積もり、納品、お取付けサポート。',
                                             '요구 협의, 규격 매칭, 샘플 검증, 견적, 납품 및 설치 사후 지원.');
  add('about.name',                          '公司名称', 'Company Name', '会社名', '회사명');
  add('about.name_desc',                     '广西亿库光养硅藻环保科技有限公司',
                                             'Guangxi Yiku Guangyang Diatom Environmental Technology Co., Ltd.',
                                             '広西億库光養硅藻環保科技有限公司',
                                             '광시 이쿠 광양 규조토 환경보호 과학기술 유한회사');
  add('about.product',                       '核心产品', 'Core Product', '主要製品', '주요 제품');
  add('about.product_desc',                  '亿库硅藻板', 'Yiku Diatom Board', '億库硅藻板', '이쿠 규조토 보드');
  add('about.scenes',                        '典型场景', 'Typical Applications', '主な活用事例', '주요 적용분야');
  add('about.scenes_desc',                   '住宅、酒店、学校、医院、商业空间、滨海工程',
                                             'Residential, Hotels, Schools, Hospitals, Commercial Spaces, Coastal Projects',
                                             '住宅、ホテル、学校、病院、商業施設、海岸工事',
                                             '주거용, 호텔, 학교, 병원, 상업용 공간, 해안 프로젝트');

  /* ── Solutions ── */
  add('solutions.heading',                   '应用场景', 'Applications', '活用事例', '적용분야');
  add('solutions.desc',                      '从家装定制到高湿、高盐雾环境，覆盖多种空间和项目需求。',
                                             'From custom home decor to high-humidity and high-salt-spray environments, covering diverse spaces and project needs.',
                                             'オーダーメイドの住宅から高湿・高塩分環境まで、さまざまな空間やプロジェクトに対応します。',
                                             '맞춤형 주거용부터 고습도, 담수 환경까지 다양한 공간과 프로젝트 요구에 대응합니다.');

  add('sol.home',                            '家装与定制', 'Residential & Custom', '住宅・オーダーメイド', '주거용 및 맞춤');
  add('sol.commercial',                      '商业空间', 'Commercial Spaces', '商業施設', '상업용 공간');
  add('sol.public',                          '公共空间', 'Public Spaces', '公共施設', '공공시설');
  add('sol.special',                         '特殊环境', 'Special Environments', '特殊環境', '특수 환경');

  /* ── Solution Items ── */
  add('sol.wall_panel',                      '墙板', 'Wall Panels', '壁パネル', '벽패널');
  add('sol.ceiling',                         '吊顶', 'Ceiling', '天井', '천장');
  add('sol.cabinet',                         '柜体', 'Cabinets', 'キャビネット', '캐비닛');
  add('sol.door_panel',                      '门板', 'Door Panels', 'ドアパネル', '문패널');
  add('sol.sliding_door',                    '移门', 'Sliding Doors', '引き戸', '미달이문');
  add('sol.kids_furniture',                  '儿童房家具', 'Children\'s Furniture', '子ども部屋の家具', '어린이 가구');
  add('sol.hotel',                           '酒店', 'Hotels', 'ホテル', '호텔');
  add('sol.club',                            '会所', 'Clubs', 'クラブ', '클럽');
  add('sol.office',                          '办公空间', 'Office Spaces', 'オフィス', '사무실');
  add('sol.store',                           '品牌门店', 'Retail Stores', 'ブランド店舗', '브랜드 매장');
  add('sol.school',                          '学校', 'Schools', '学校', '학교');
  add('sol.hospital',                        '医院', 'Hospitals', '病院', '병원');
  add('sol.lab',                             '实验室', 'Laboratories', '研究室', '연구실');
  add('sol.meeting_room',                    '会议室', 'Meeting Rooms', '会議室', '회의실');
  add('sol.theater',                         '剧院', 'Theaters', '劇場', '극장');
  add('sol.marine_dock',                     '滨海码头', 'Marine Docks', '海岸岸壁', '해안 부두');
  add('sol.ship_interior',                   '船舶内装', 'Ship Interiors', '船舶内装', '선박 인테리어');
  add('sol.humid_area',                      '潮湿区域', 'Humid Areas', '湿気の多い場所', '습윤 지역');
  add('sol.cold_storage',                    '冷库', 'Cold Storage', '冷凍倉庫', '냉동창고');
  add('sol.fire_zone',                       '高防火区域', 'High Fire-Safety Zones', '防火重要区域', '고방염 구역');

  /* ── Cases ── */
  add('cases.heading',                       '真实案例', 'Real Cases', '実例紹介', '실제 사례');
  add('cases.desc',                          '优先展示酒店、学校、住宅和滨海环境场景，让客户更容是理解实际落地效果。',
                                             'We highlight hotel, school, residential, and coastal projects to help clients better understand real-world results.',
                                             'ホテル、学校、住宅、海岸環境の事例を優先して紹介し、お客様が実際の効果をより理解しやすくします。',
                                             '호텔, 학교, 주거용, 해안 환경 사례를 중심으로 소개하여 고객이 실제 효과를 쉽게 이해할 수 있도록 합니다.');
  add('cases.hotel',                         '酒店案例', 'Hotel Case', 'ホテル事例', '호텔 사례');
  add('cases.hotel_desc',                    '适合强调空间质感、健康环保与静音体验的住宿场景。',
                                             'Ideal for accommodation spaces emphasizing texture, health, eco-friendliness and quiet experience.',
                                             '素材感、健康環保、静かな体験を強調する宿泊施設に最適です。',
                                             '질감, 건강한 환경, 조용한 체험을 중요시 하는 숙박 공간에 적합합니다.');
  add('cases.school',                        '学校案例', 'School Case', '学校事例', '학교 사례');
  add('cases.school_desc',                   '适合兼顾吸音降噪、抗菌环保和耐久性的教学与会议空间。',
                                             'Suitable for teaching and meeting spaces requiring sound absorption, antibacterial properties, eco-friendliness and durability.',
                                             '吸音、抗菌、環保、耐久性が求められる教室や会議室に適します。',
                                             '흡음, 항균, 친환경, 내구성이 필요한 교육 및 회의 공간에 적합합니다.');
  add('cases.residential',                   '住宅案例', 'Residential Case', '住宅事例', '주거용 사례');
  add('cases.residential_desc',              '适合内装配式装修与全屋空间，突出舒适度和长期居住体验。',
                                             'Ideal for interior modular decoration and whole-house spaces, focusing on comfort and long-term living experience.',
                                             '内装工法と住宅全体に適し、快適さと長期的な住体験を強調します。',
                                             '실내 모듈러 인테리어와 전체 주거용 공간에 적합하며 편안함과 장기 거주 체험을 강조합니다.');
  add('cases.marine',                        '海洋场景案例', 'Marine Environment Case', '海洋環境事例', '해양 환경 사례');
  add('cases.marine_desc',                   '适合海洋牧场、滨海设施和高盐雾环境，强化耐腐蚀与稳定性。',
                                             'Ideal for marine ranches, coastal facilities and high-salt-spray environments, with enhanced corrosion resistance and stability.',
                                             '海洋牧場、海岸施設、高塩分環境に適し、耐食性と安定性を向上させます。',
                                             '해양 목장, 해안 시설, 고염분 환경에 적합하며 부식 방지와 안정성이 향상됩니다.');

  /* ── Product Detail ── */
  add('detail.heading',                      '产品细节展示', 'Product Details', '製品詳細', '제품 상세');
  add('detail.desc',                         '用真实产品图替代概念图，让客户更快判断材质、厚度和适用方向。',
                                             'Using real product images instead of concept renders, helping clients quickly assess material, thickness, and suitable applications.',
                                             'コンセプト画像ではなく実際の製品画像を使用し、お客様が素材、厚さ、適用方向を簡単に判断できるようにします。',
                                             '실제 제품 이미지를 사용하여 고객이 재질, 두께, 적용 분야를 빠르게 판단할 수 있습니다.');
  add('detail.title',                        '从样品质感到项目匹配',
                                             'From Sample Texture to Project Matching',
                                             'サンプルの質感からプロジェクトマッチングへ',
                                             '샘플 질감부터 프로젝트 매칭까지');
  add('detail.desc_long',                    '硅藻素板适合作为首页的核心产品主图。它能直接传达板材外观、厚度和基础材质感，比抽象效果图更利于客户快速建立认知。',
                                             'The diatom base board works well as the primary product image for the homepage. It directly conveys the panel appearance, thickness and base material texture, helping customers build understanding faster than abstract renderings.',
                                             '硅藻素板はホームページのメイン製品画像として最適です。パネルの外観、厚さ、素材感を直接伝え、抽象的な効果図よりもお客様の理解を促します。',
                                             '규조토 베이스 패널은 메인 페이지의 주요 제품 이미지로 적합합니다. 패널의 외관, 두께, 재질감을 직접 전달하여 추상적인 렌더링보다 고객의 이해를 돕습니다.');
  add('detail.item1',                        '可用于墙板、吊顶、门板、家具与内装配式装修',
                                             'Suitable for wall panels, ceilings, door panels, furniture and interior modular decoration.',
                                             '壁パネル、天井、ドア、家具、内装モジュールに使用可能。',
                                             '벽패널, 천장, 문패널, 가구, 실내 모듈러 인테리어에 사용 가능합니다.');
  add('detail.item2',                        '支持围绕厚度、安装方式和空间功能进行组合匹配',
                                             'Supports combination matching based on thickness, installation method, and space function.',
                                             '厚さ、取付け方法、空間機能に応じた組み合わせが可能です。',
                                             '두께, 설치 방법, 공간 기능에 따라 조합 매칭이 가능합니다.');
  add('detail.item3',                        '适合与案例区和咨询入口一起使用，形成转化闭环',
                                             'Works together with case studies and inquiry entry points to form a conversion loop.',
                                             '事例セクションやお問い合わせ窓口と組み合わせて、コンバージョンループを形成します。',
                                             '사례 영역과 문의 창구와 함께 사용하여 전환 루프를 구축합니다.');

  /* ── Process ── */
  add('process.heading',                     '合作流程', 'Our Process', '協業プロセス', '협력 프로세스');
  add('process.desc',                        '把方案沟通、样品验证、报价交付和售后支持串成完整的服务过程。',
                                             'A complete service journey: from requirement discussion, sample verification, and quotation delivery to after-sales support.',
                                             '要件確認からサンプル検証、お見積もり、アフターサポートまで一貫したサービスプロセス。',
                                             '요구 협의부터 샘플 검증, 견적, 납품, 사후 지원까지 완전한 서비스 과정입니다.');
  add('process.step1',                       '需求沟通', 'Requirements', '要件確認', '요구 협의');
  add('process.step1_desc',                  '围绕场景、预算、功能优先级和施工条件做基础判断。',
                                             'Basic evaluation covering application scenarios, budget, functional priorities and construction conditions.',
                                             '活用シーン、予算、機能の優先順位、施工条件に基づいた基礎評価を行います。',
                                             '적용 분야, 예산, 기능 우선순위, 시공 조건에 따른 기본 평가를 진행합니다.');
  add('process.step2',                       '规格匹配', 'Spec Matching', '仕様マッチング', '규격 매칭');
  add('process.step2_desc',                  '结合板型、厚度、安装方式和项目节奏给出匹配建议。',
                                             'Recommendations based on panel type, thickness, installation method and project timeline.',
                                             'パネルタイプ、厚さ、取付け方法、プロジェクトスケジュールに応じた提案を行います。',
                                             '패널 유형, 두께, 설치 방법, 프로젝트 일정에 따라 추천 사항을 제시합니다.');
  add('process.step3',                       '样品验证', 'Sample Verification', 'サンプル確認', '샘플 검증');
  add('process.step3_desc',                  '通过样品、案例和资料完成前期确认。',
                                             'Preliminary confirmation through samples, case studies and documentation.',
                                             'サンプル、事例、資料による事前確認を行います。',
                                             '샘플, 사례, 자료를 통한 사전 확인을 진행합니다.');
  add('process.step4',                       '报价交付', 'Quote & Delivery', 'お見積もり・納品', '견적 및 납품');
  add('process.step4_desc',                  '明确规格、数量、交付节点与后续配合方式。',
                                             'Clarifying specifications, quantities, delivery milestones and ongoing support arrangements.',
                                             '仕様、数量、納期、引き続きのサポート体制を明確にします。',
                                             '규격, 수량, 납기, 향후 지원 방법을 명확히 합니다.');

  /* ── Contact ── */
  add('contact.heading',                     '联系亿库团队', 'Contact Yiku Team', '億库チームへのお問い合わせ', '이쿠 팀에게 문의');
  add('contact.desc',                        '适合项目咨询、规格沟通、报价评估、渠道合作和样品对接。',
                                             'For project inquiries, specification discussions, quotation assessment, channel cooperation, and sample coordination.',
                                             'プロジェクトのご相談、仕様のご確認、お見積もり、チャネル協業、サンプル対応にご利用ください。',
                                             '프로젝트 상담, 규격 협의, 견적 평가, 유통 협력, 샘플 조율에 해당합니다.');

  /* ── Footer ── */
  add('footer.tagline',                      '环保功能型板材方案，服务家装、工装、公共空间与特殊环境项目。',
                                             'Eco-friendly functional panel solutions serving residential, commercial, public space, and special environment projects.',
                                             '環保機能型パネルソリューション、住宅・商業施設・公共施設・特殊環境プロジェクトへのサービス。',
                                             '친환경 기능성 패널 솔루션으로 주거용, 상업용, 공공시설, 특수 환경 프로젝트를 지원합니다.');
  add('footer.contact_title',                '联系方式', 'Contact', 'お問い合わせ', '연락처');
  add('footer.phone1',                       '招商热线：0779-8525688', 'Sales: 0779-8525688', 'お問い合わせ：0779-8525688', '문의전화: 0779-8525688');
  add('footer.phone2',                       '联系电话：18169771178', 'Tel: 18169771178', '電話番号：18169771178', '전화번호: 18169771178');
  add('footer.address_title',                '地址', 'Address', '住所', '주소');
  add('footer.address',                      '广西北海海洋研究创新园科研一路 B1-1 栋',
                                             'Bldg B1-1, Keyan 1st Rd, Marine Research Innovation Park, Beihai, Guangxi',
                                             '広西北海海洋研究イノベーションパーク科研一路 B1-1幢4',
                                             '광시 북해 해양연구혁신단지 과연일로 B1-1동');
  add('footer.copyright',                    'Copyright © 2020 - （年份自动更新） 广西亿库光养硅藻环保科技有限公司',
                                             'Copyright © 2020 - (auto year) Guangxi Yiku Guangyang Diatom Environmental Technology Co., Ltd.',
                                             'Copyright © 2020 - (年自動更新) 広西億库光養硅藻環保科技有限公司',
                                             'Copyright © 2020 - (연도 자동 갱신) 광시 이쿠 광양 규조토 환경보호 과학기술 유한회사');

  /* ── Auth Modal ── */
  add('auth.login',                          '登录', 'Login', 'ログイン', '로그인');
  add('auth.register',                       '注册', 'Register', '登録', '회원가입');
  add('auth.email',                          '邮箱', 'Email', 'メールアドレス', '이메일');
  add('auth.password',                       '密码', 'Password', 'パスワード', '비밀번호');
  add('auth.password_hint',                  '密码（至少 6 位）', 'Password (min. 6 characters)', 'パスワード（6桁以上）', '비밀번호 (6자 이상)');
  add('auth.nickname',                       '昵称（选填）', 'Nickname (optional)', 'ニックネーム（任意）', '닉네임 (선택사항)');
  add('auth.get_code',                       '获取验证码', 'Get Verification Code', '認証コードを取得', '인증번호 받기');
  add('auth.verify_activate',                '验证并激活', 'Verify & Activate', '認証して有効化', '인증 및 활성화');
  add('auth.forgot_password',                '忘记密码？', 'Forgot password?', 'パスワードをお忘れですか？', '비밀번호를 잊으션나요?');
  add('auth.code_sent',                      '验证码已发送至', 'Code sent to', '認証コードを送信しました：', '인증번호가 전송됨:');
  add('auth.code_sent_full',                 '验证码已发送至您的邮箱，10分钟内有效',
                                             'A verification code has been sent to your email. Valid for 10 minutes.',
                                             '認証コードをメールで送信しました。（10分間有効）',
                                             '인증번호가 이메일로 전송되었습니다. 10분 내에 유효합니다.');
  add('auth.check_spam',                     '如未收到请检查垃圾邮件箱',
                                             'If not received, please check your spam folder.',
                                             '受信しない場合は、迷惑メールフォルダをご確認ください。',
                                             '수신하지 못한 경우 스팸함을 확인해 주세요.');
  add('auth.code_placeholder',               '6 位验证码', '6-digit code', '6桁認証コード', '6자리 인증번호');
  add('auth.reset_code_sent',                '重置验证码已发送至',
                                             'Password reset code sent to',
                                             'パスワードリセットコードを送信しました：',
                                             '비밀번호 재설정 인증번호가 전송됨:');
  add('auth.reset_password_btn',             '重置密码', 'Reset Password', 'パスワードをリセット', '비밀번호 재설정');
  add('auth.new_password',                   '新密码（至少 6 位）', 'New password (min. 6 characters)', '新しいパスワード（6桁以上）', '새 비밀번호 (6자 이상)');
  add('auth.enter_email',                    '输入注册邮箱，我们将发送重置验证码',
                                             'Enter your registered email and we\'ll send a reset code.',
                                             '登録メールアドレスを入力してください。リセットコードを送信します。',
                                             '등록된 이메일을 입력하시면 재설정 인증번호를 보내드립니다.');
  add('auth.login_failed',                   '登录失败', 'Login failed', 'ログインに失敗しました', '로그인 실패');
  add('auth.register_failed',                '注册失败', 'Registration failed', '登録に失敗しました', '회원가입 실패');
  add('auth.verify_failed',                  '验证失败', 'Verification failed', '認証に失敗しました', '인증 실패');
  add('auth.send_failed',                    '发送失败', 'Send failed', '送信に失敗しました', '전송 실패');
  add('auth.reset_failed',                   '重置失败', 'Reset failed', 'リセットに失敗しました', '재설정 실패');
  add('auth.network_error',                  '网络错误，请稍后重试',
                                             'Network error. Please try again later.',
                                             'ネットワークエラー。少し後に再試行してください。',
                                             '네트워크 오류. 다시 시도해 주세요.');
  add('auth.password_reset_ok',              '密码已重置，请用新密码登录',
                                             'Password has been reset. Please log in with your new password.',
                                             'パスワードがリセットされました。新しいパスワードでログインしてください。',
                                             '비밀번호가 재설정되었습니다. 새 비밀번호로 로그인하세요.');
  add('auth.logout_confirm',                 '确定要退出登录吗？',
                                             'Are you sure you want to log out?',
                                             'ログアウトしますか？',
                                             '정말 로그아웃 하시겠습니?');
  add('auth.logged_in',                      '已登录', 'Logged in', 'ログイン済み', '로그인됨');

  /* ── Image Errors ── */
  add('img.unsupported_format',              '仅支持 PNG、JPEG、WebP 格式的图片',
                                             'Only PNG, JPEG, and WebP formats are supported.',
                                             'PNG、JPEG、WebP形式のみ対応しています。',
                                             'PNG, JPEG, WebP 형식만 지원됩니다.');
  add('img.too_large',                       '图片大小不能超过 10MB',
                                             'Image size must not exceed 10MB.',
                                             '画像サイズは10MB以内にしてください。',
                                             '이미지 크기는 10MB를 초과할 수 없습니다.');
  add('img.too_large_short',                 '图片不超过10MB',
                                             'Image must not exceed 10MB.',
                                             '画像は10MB以内',
                                             '이미지 10MB 이하');

  /* ── Chat Page Specific ── */
  add('chatpage.chat',                       '在线咨询', 'Online Chat', 'オンライン相談', '온라인상담');
  add('chatpage.send',                       '发送', 'Send', '送信', '보내기');
  add('chatpage.login_required',             '免费咨询次数已用完，请登录后继续。',
                                             'Free consultations exhausted. Please log in to continue.',
                                             '無料相談回数が上限に達しました。ログインして続けてください。',
                                             '무료 상담 횟수가 초과되었습니다. 로그인하여 계속하세요.');

  /* ── Product Detail Image Alt ── */
  add('alt.logo',                            '亿库 logo', 'Yiku logo', '億库ロゴ', '이쿠 로고');
  add('alt.product_detail',                  '亿库硅藻板产品细节图',
                                             'Yiku diatom board product detail',
                                             '億库硅藻板製品詳細画像',
                                             '이쿠 규조토 보드 제품 상세 이미지');
  add('alt.chat_image',                      '发送的图片', 'Sent image', '送信した画像', '보낸 이미지');
  add('alt.online_chat',                     '在线客服', 'Online support', 'オンラインサポート', '온라인 고객지원');

  /* ── Chat Page Title ── */
  add('chatpage.title',                      '亿库 AI 客服', 'Yiku AI Assistant', '億库 AIアシスタント', '이쿠 AI 상담');

  /* ── Landing page Chat ── */
  add('chat.alt.return_home',                '返回首页', 'Return to homepage', 'ホームに戻る', '홈으로 돌아가기');

  /* ── Helper function to populate all four languages ── */
  function add(key, zh, en, ja, ko) {
    DICT['zh-CN'][key] = zh;
    DICT['en-US'][key] = en;
    DICT['ja-JP'][key] = ja;
    DICT['ko-KR'][key] = ko;
  }

  /* ── Current language ── */
  var currentLang = DEFAULT;

  function detect() {
    var stored = localStorage.getItem(STORAGE_KEY);
    if (stored && SUPPORTED.indexOf(stored) !== -1) return stored;
    try {
      var bl = (navigator.language || navigator.userLanguage || '').toLowerCase();
      if (bl.indexOf('zh') === 0) return 'zh-CN';
      if (bl.indexOf('ja') === 0) return 'ja-JP';
      if (bl.indexOf('ko') === 0) return 'ko-KR';
      if (bl.indexOf('en') === 0) return 'en-US';
    } catch (e) { /* ignore */ }
    return DEFAULT;
  }

  function getLang() {
    return currentLang;
  }

  function setLang(lang, persist) {
    if (SUPPORTED.indexOf(lang) === -1) return;
    currentLang = lang;
    if (persist !== false) {
      try { localStorage.setItem(STORAGE_KEY, lang); } catch (e) { /* ignore */ }
    }
    apply();
  }

  function t(key) {
    return (DICT[currentLang] && DICT[currentLang][key]) ||
           (DICT[DEFAULT] && DICT[DEFAULT][key]) ||
           key;
  }

  function apply() {
    document.documentElement.setAttribute('lang', currentLang);

    /* Update document title */
    var titleKey = 'site.title';
    if (document.body && document.body.getAttribute('data-page') === 'chat') {
      titleKey = 'chatpage.title';
    }
    var titleText = t(titleKey);
    if (titleText && titleText !== titleKey) {
      document.title = titleText;
    }

    /* textContent */
    var els = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < els.length; i++) {
      var key = els[i].getAttribute('data-i18n');
      if (key) els[i].textContent = t(key);
    }

    /* placeholder */
    els = document.querySelectorAll('[data-i18n-placeholder]');
    for (i = 0; i < els.length; i++) {
      key = els[i].getAttribute('data-i18n-placeholder');
      if (key) els[i].setAttribute('placeholder', t(key));
    }

    /* title attribute */
    els = document.querySelectorAll('[data-i18n-title]');
    for (i = 0; i < els.length; i++) {
      key = els[i].getAttribute('data-i18n-title');
      if (key) els[i].setAttribute('title', t(key));
    }

    /* alt attribute */
    els = document.querySelectorAll('[data-i18n-alt]');
    for (i = 0; i < els.length; i++) {
      key = els[i].getAttribute('data-i18n-alt');
      if (key) els[i].setAttribute('alt', t(key));
    }

    /* aria-label attribute */
    els = document.querySelectorAll('[data-i18n-aria-label]');
    for (i = 0; i < els.length; i++) {
      key = els[i].getAttribute('data-i18n-aria-label');
      if (key) els[i].setAttribute('aria-label', t(key));
    }

    /* Update language switcher UI */
    updateSwitchers();
  }

  function updateSwitchers() {
    /* Update toggle button text */
    var toggles = document.querySelectorAll('.lang-switcher-toggle, .lang-switcher-mobile-toggle');
    for (var i = 0; i < toggles.length; i++) {
      var flagEl = toggles[i].querySelector('.lang-flag');
      var nameEl = toggles[i].querySelector('.lang-name');
      if (flagEl) flagEl.textContent = FLAGS[currentLang] || '';
      if (nameEl) nameEl.textContent = NAMES[currentLang] || currentLang;
    }

    /* Highlight active language in menu */
    var buttons = document.querySelectorAll('.lang-switcher-menu button, .lang-switcher-mobile-menu button');
    for (i = 0; i < buttons.length; i++) {
      var btnLang = buttons[i].getAttribute('data-lang');
      if (btnLang === currentLang) {
        buttons[i].classList.add('active');
      } else {
        buttons[i].classList.remove('active');
      }
    }
  }

  /* ── Expose API ── */
  window.I18N = {
    SUPPORTED: SUPPORTED,
    DEFAULT: DEFAULT,
    FLAGS: FLAGS,
    NAMES: NAMES,
    STORAGE_KEY: STORAGE_KEY,
    detect: detect,
    getLang: getLang,
    setLang: setLang,
    t: t,
    apply: apply,
    updateSwitchers: updateSwitchers
  };

  /* ── Initialize language and auto-apply ── */
  currentLang = detect();

  function ready() {
    apply();
    /* Attach language switcher event listeners */
    document.addEventListener('click', function(e) {
      /* Toggle menu */
      var toggle = e.target.closest('.lang-switcher-toggle, .lang-switcher-mobile-toggle');
      if (toggle) {
        e.stopPropagation();
        var menu = toggle.parentElement.querySelector('.lang-switcher-menu, .lang-switcher-mobile-menu');
        if (menu) {
          var isOpen = !menu.hidden;
          menu.hidden = isOpen;
          toggle.setAttribute('aria-expanded', String(!isOpen));
        }
        return;
      }

      /* Select language */
      var langBtn = e.target.closest('.lang-switcher-menu button, .lang-switcher-mobile-menu button');
      if (langBtn) {
        var lang = langBtn.getAttribute('data-lang');
        if (lang) {
          setLang(lang);
          /* Close all menus */
          var menus = document.querySelectorAll('.lang-switcher-menu, .lang-switcher-mobile-menu');
          for (var i = 0; i < menus.length; i++) {
            menus[i].hidden = true;
          }
          var toggles = document.querySelectorAll('.lang-switcher-toggle, .lang-switcher-mobile-toggle');
          for (i = 0; i < toggles.length; i++) {
            toggles[i].setAttribute('aria-expanded', 'false');
          }
        }
        return;
      }

      /* Click outside closes menus */
      if (!e.target.closest('.lang-switcher') && !e.target.closest('.lang-switcher-mobile')) {
        var menus = document.querySelectorAll('.lang-switcher-menu, .lang-switcher-mobile-menu');
        for (var i = 0; i < menus.length; i++) {
          menus[i].hidden = true;
        }
        var toggles = document.querySelectorAll('.lang-switcher-toggle, .lang-switcher-mobile-toggle');
        for (i = 0; i < toggles.length; i++) {
          toggles[i].setAttribute('aria-expanded', 'false');
        }
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ready);
  } else {
    ready();
  }
})();
