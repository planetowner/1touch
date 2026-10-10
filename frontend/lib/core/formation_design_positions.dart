import 'dart:ui';

// Formations 페이지의 345 × 392 프레임에서 읽은 원 중심 좌표예요.
// https://www.figma.com/design/hmzoiWMvmYaHoJ4gJ6AxNA/1Touch?node-id=2346-32530
// 시안마다 다른 줄 높이와 간격을 유지하고, 완전히 같은 줄만 함께 사용해요.
// 4-3-3은 기존 규칙대로 4-1-2-3을 사용하므로 별도 좌표를 두지 않아요.
const formationDesignRows = <String, List<List<Offset>>>{
  '2-3-2-1-2': [
    [Offset(124, 256), Offset(222, 256)],
    [Offset(48, 202), Offset(173, 202), Offset(298, 202)],
    [Offset(112, 148), Offset(234, 148)],
    [Offset(173, 94)],
    [Offset(112, 40), Offset(234, 40)],
  ],
  '3-1-4-2': [
    [Offset(80, 250), Offset(173, 250), Offset(266, 250)],
    [Offset(173, 180)],
    [Offset(56, 110), Offset(134, 110), Offset(212, 110), Offset(290, 110)],
    [Offset(132, 40), Offset(214, 40)],
  ],
  '3-2-3-2': [
    [Offset(78, 256), Offset(173, 256), Offset(265.5, 256)],
    [Offset(124, 184), Offset(222, 184)],
    [Offset(56, 112), Offset(173, 118), Offset(290, 112)],
    _forwardPair,
  ],
  '3-2-4-1': [
    [Offset(78, 260), Offset(173, 260), Offset(265.5, 260)],
    [Offset(132, 186), Offset(214, 186)],
    [Offset(50, 96), Offset(132, 112), Offset(214, 112), Offset(296, 96)],
    _singleForward,
  ],
  '3-3-1-3': [
    [Offset(74, 256), Offset(173, 256), Offset(269.5, 256)],
    [Offset(96, 184), Offset(173, 184), Offset(250, 184)],
    [Offset(173, 112)],
    [Offset(48, 56), Offset(173, 40), Offset(298, 56)],
  ],
  '3-3-2-2': [
    [Offset(62, 262), Offset(173, 262), Offset(281.5, 262)],
    [Offset(96, 188), Offset(173, 188), Offset(250, 188)],
    [Offset(132, 114), Offset(214, 114)],
    _forwardPair,
  ],
  '3-3-3-1': [
    [Offset(78, 262), Offset(173, 262), Offset(265.5, 262)],
    [Offset(100, 188), Offset(173, 188), Offset(246, 188)],
    [Offset(72, 114), Offset(173, 114), Offset(274, 114)],
    _singleForward,
  ],
  '3-4-1-2': [
    [Offset(78, 252), Offset(173, 260), Offset(265.5, 252)],
    [Offset(47, 176), Offset(132, 184), Offset(212.5, 184), Offset(298, 176)],
    [Offset(173, 108)],
    _forwardPair,
  ],
  '3-4-2-1': [
    [Offset(80, 258), Offset(173, 258), Offset(266, 258)],
    [Offset(52, 180), Offset(134, 188), Offset(209.5, 188), Offset(293, 180)],
    [Offset(120, 110), Offset(226, 110)],
    _singleForward,
  ],
  '3-4-3': [
    [Offset(80, 248), Offset(173, 256), Offset(266, 248)],
    [Offset(49.5, 154), Offset(133, 170), Offset(215, 170), Offset(297, 154)],
    [Offset(80, 76), Offset(173, 40), Offset(266, 76)],
  ],
  '3-5-1-1': [
    [Offset(76, 264), Offset(173, 264), Offset(270, 264)],
    [
      Offset(48, 144),
      Offset(108, 192),
      Offset(173, 192),
      Offset(238, 192),
      Offset(298, 144)
    ],
    [Offset(173, 108)],
    _singleForward,
  ],
  '3-5-2': [
    [Offset(80, 256), Offset(173, 256), Offset(266, 256)],
    [
      Offset(48, 148),
      Offset(116, 168),
      Offset(173, 128),
      Offset(230, 168),
      Offset(298, 148)
    ],
    _forwardPair,
  ],
  '4-1-2-1-2': [
    [Offset(48, 224), Offset(132, 256), Offset(214, 256), Offset(298, 224)],
    [Offset(173, 176)],
    [Offset(99.5, 140), Offset(247, 140)],
    [Offset(173, 104)],
    _forwardPair,
  ],
  '4-1-2-3': [
    _backFour,
    [Offset(173, 184)],
    [Offset(124, 128), Offset(222, 128)],
    [Offset(48, 76), Offset(173, 40), Offset(298, 76)],
  ],
  '4-1-3-2': [
    _backFour,
    [Offset(173, 176)],
    [Offset(48, 108), Offset(173, 108), Offset(298, 108)],
    _forwardPair,
  ],
  '4-1-4-1': [
    _backFour,
    [Offset(173, 188)],
    [Offset(48, 104), Offset(132, 120), Offset(214, 120), Offset(298, 104)],
    _singleForward,
  ],
  '4-2-1-3': [
    [Offset(48, 232), Offset(128, 264), Offset(218, 264), Offset(298, 232)],
    [Offset(128, 176), Offset(218, 176)],
    [Offset(173, 112)],
    [Offset(56, 64), Offset(173, 40), Offset(290, 64)],
  ],
  '4-2-2-2': [
    _backFour,
    [Offset(120, 178), Offset(226, 178)],
    [Offset(120, 108), Offset(226, 108)],
    [Offset(120, 40), Offset(226, 40)],
  ],
  '4-2-3-1': [
    _backFour,
    [Offset(116, 172), Offset(230, 172)],
    [Offset(48, 96), Offset(173, 112), Offset(298, 96)],
    _singleForward,
  ],
  '4-2-4': [
    _backFour,
    [Offset(132, 152), Offset(214, 152)],
    [Offset(48, 84), Offset(124, 40), Offset(222, 40), Offset(298, 84)],
  ],
  '4-3-1-2': [
    [Offset(48, 236), Offset(132, 260), Offset(214, 260), Offset(298, 236)],
    [Offset(88, 168), Offset(173, 184), Offset(258, 168)],
    [Offset(173, 108)],
    _forwardPair,
  ],
  '4-3-2-1': [
    [Offset(48, 238), Offset(132, 268), Offset(214, 268), Offset(298, 238)],
    [Offset(90, 172), Offset(173, 200), Offset(253.5, 172)],
    [Offset(131.5, 106), Offset(215, 106)],
    _singleForward,
  ],
  '4-4-1-1': [
    _backFour,
    [Offset(52, 148), Offset(132, 172), Offset(214, 172), Offset(294, 148)],
    [Offset(173, 104)],
    _singleForward,
  ],
  '4-4-2': [
    _backFour,
    [Offset(52, 112), Offset(132, 160), Offset(214, 160), Offset(294, 112)],
    _forwardPair,
  ],
  '4-5-1': [
    _backFour,
    [
      Offset(46, 106),
      Offset(105, 154),
      Offset(173, 130),
      Offset(240, 154),
      Offset(299, 106)
    ],
    _singleForward,
  ],
  '5-2-3': [
    [
      Offset(45, 224),
      Offset(107, 256),
      Offset(173, 256),
      Offset(239, 256),
      Offset(295, 224)
    ],
    [Offset(120, 156), Offset(226, 156)],
    [Offset(48, 78), Offset(173, 40), Offset(298, 78)],
  ],
  '5-3-1-1': [
    _backFive,
    [Offset(94, 154), Offset(173, 178), Offset(249.5, 154)],
    [Offset(173, 102)],
    _singleForward,
  ],
  '5-3-2': [
    [
      Offset(48, 226),
      Offset(104, 256),
      Offset(171, 256),
      Offset(242, 256),
      Offset(298, 226)
    ],
    [Offset(90, 126), Offset(173, 166), Offset(253.5, 126)],
    _forwardPair,
  ],
  '5-4-1': [
    _backFive,
    [Offset(50, 122), Offset(132, 154), Offset(214, 154), Offset(295, 122)],
    _singleForward,
  ],
};

const _backFour = [
  Offset(48, 220),
  Offset(132, 252),
  Offset(214, 252),
  Offset(298, 220)
];
const _singleForward = [Offset(173, 40)];
const _forwardPair = [Offset(124, 40), Offset(222, 40)];
const _backFive = [
  Offset(48, 224),
  Offset(107, 256),
  Offset(173, 256),
  Offset(239, 256),
  Offset(298, 224)
];
