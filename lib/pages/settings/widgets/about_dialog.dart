import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:think_nest/common/index.dart';

class AboutDialogWidget extends StatelessWidget {
  const AboutDialogWidget({super.key});

  static const String aboutContent = '''
思巢（Think Nest）米果空间“成长之光”涵盖AR、体感、红外、雷达等多种互动模式全智能科教系统及逾百种课程设计方案，为学前教育提供多种知识探索场景和互动体验课程内容。课程设置旨在通过互动式课程体验和实景模拟场景，科学地将一体化智能互动游戏与儿童多方面科学数据测评相结合，以挖掘和培养儿童多种潜在的能力及天赋，打造一个专属于儿童的“超媒体科探室”。

米果空间“成长之光”课程内容由专家团队为3-6岁儿童量身定制，团队顾问由多名学前教育专家及儿童心理学专家组成。游戏教学遵循科学的教育方式，从视、听、说、触想等多感触体验角度出发，与儿童分享一个多角度、多层维、多信息的科学课堂，激发儿童无限的学习情怀，还能帮助授学者更全面、更准确、更科学地进行知识讲解！在学习方式上，将科技与传统相结合，让先进的教育方式与科技的智能互动体验并行携手步入教育4.0时代。

米果空间“成长之光”，可以体验多种学习场景。在学习过程中教室将化身为科技馆，通过智能互动技术，在不同的课程中，不管是奇趣的大自然，或者是音乐世界，或者太空奇幻，都能让小朋友身临其境并且有各种奇幻的互动惊喜体验。

让教育携科技领航，让未来因成长发光。
''';
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1760.w,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 38.h),
      child: TextWidget.label(
        aboutContent,
        size: 32.w,
        textStyle: TextStyle(
          letterSpacing: 1.w,
          height: 60.w / 32.w,
        ),
      ),
    );
  }
}
