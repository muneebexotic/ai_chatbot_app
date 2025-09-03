// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AI 聊天机器人';

  @override
  String get settings => '设置';

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get done => '完成';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String get signUp => '注册';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get sendMessage => '发送';

  @override
  String get chatHistory => '聊天记录';

  @override
  String get newChat => '新聊天';

  @override
  String get accountInformation => '账户信息';

  @override
  String get appearance => '外观';

  @override
  String get preferences => '偏好设置';

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get securitySupport => '安全与支持';

  @override
  String get errorGeneral => '出现错误，请重试。';

  @override
  String get errorNetwork => '网络错误，请检查您的连接。';

  @override
  String get errorAuth => '身份验证失败，请重试。';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageChinese => '中文';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get phoneNumber => '电话号码';

  @override
  String get upgradeToPlusTitle => '升级到 Plus';

  @override
  String get upgradeToPlusSubtitle => '解锁高级功能';

  @override
  String get personalizationTitle => '个性化';

  @override
  String get personalizationSubtitle => '自定义您的体验';

  @override
  String get dataControlsTitle => '数据控制';

  @override
  String get dataControlsSubtitle => '管理您的数据';

  @override
  String get voiceTitle => '语音';

  @override
  String get voiceSubtitle => '语音设置和偏好';

  @override
  String get securityTitle => '安全';

  @override
  String get securitySubtitle => '隐私和安全设置';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutSubtitle => '应用信息和版本';

  @override
  String get signOutSubtitle => '退出您的账户';

  @override
  String get signOutDialogTitle => '退出登录';

  @override
  String get signOutDialogMessage => '您确定要退出登录吗？';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get welcomeBack => '欢迎';

  @override
  String get backText => '回来';

  @override
  String get emailHint => '请输入您的邮箱';

  @override
  String get passwordHint => '请输入您的密码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get login => '登录';

  @override
  String get dontHaveAccount => '还没有账户？ ';

  @override
  String get orContinueWith => '或继续使用';

  @override
  String get createYour => '创建您的';

  @override
  String get account => '账户';

  @override
  String get fullName => '全名';

  @override
  String get fullNameHint => '请输入您的全名';

  @override
  String get alreadyHaveAccount => '已有账户？ ';

  @override
  String get exitApp => '退出应用？';

  @override
  String get exitAppMessage => '您确定要退出应用吗？';

  @override
  String get conversationsSaved => '您的对话将被保存，返回时可用。';

  @override
  String get exit => '退出';

  @override
  String get howCanIHelp => '今天我能为您做些什么？';

  @override
  String get chooseTopicOrType => '选择下面的话题或开始输入您的问题';

  @override
  String get quickSuggestions => '快速建议';

  @override
  String get dailyUsage => '每日使用';

  @override
  String get generateImage => '生成图像';

  @override
  String get describeWhatYouWant => '描述您想要创建的内容：';

  @override
  String get imagePromptHint => '例如：山上美丽的日落，数字艺术风格';

  @override
  String get imagePromptTip => '请具体描述！包含风格、情绪、颜色和细节以获得更好的结果。';

  @override
  String get generate => '生成';

  @override
  String get voiceLimitReached => '语音限制已达到';

  @override
  String get messageLimitReached => '消息限制已达到';

  @override
  String get imageLimitReached => '图像生成限制已达到';

  @override
  String upgradeForUnlimited(String feature) {
    return '升级到高级版以获得无限$feature！';
  }

  @override
  String get premiumBenefits => '高级版权益：';

  @override
  String get unlimitedMessages => '• 无限消息';

  @override
  String get unlimitedImagesVoice => '• 无限图像和语音';

  @override
  String get allPersonasUnlocked => '• 所有角色已解锁';

  @override
  String get prioritySupport => '• 优先支持';

  @override
  String get later => '稍后';

  @override
  String get upgradeNow => '立即升级';

  @override
  String get microphoneNotAvailable => '麦克风不可用';

  @override
  String failedToSendMessage(String error) {
    return '发送消息失败：$error';
  }

  @override
  String failedToGenerateImage(String error) {
    return '生成图像失败：$error';
  }
}
