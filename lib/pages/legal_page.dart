import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

enum LegalType { privacy, terms, community }

class LegalPage extends StatelessWidget {
  final LegalType type;

  const LegalPage({super.key, required this.type});

  String _title() {
    switch (type) {
      case LegalType.privacy:
        return 'Privacy Policy';
      case LegalType.terms:
        return 'Terms of Service';
      case LegalType.community:
        return 'Community Guidelines';
    }
  }

  String _lastUpdated() => 'Last updated: May 6, 2026';

  String _content() {
    switch (type) {
      case LegalType.privacy:
        return _privacyPolicy;
      case LegalType.terms:
        return _termsOfService;
      case LegalType.community:
        return _communityGuidelines;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.background,
      appBar: AppBar(
        backgroundColor: KokColors.surface,
        elevation: 0,
        title: Text(
          _title(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: KokColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: KokColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lastUpdated(),
              style: const TextStyle(fontSize: 12, color: KokColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              _content(),
              style: const TextStyle(
                fontSize: 14,
                color: KokColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'KOK - Korean\'s real view On K-pop\nContact: heeya00910@gmail.com',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: KokColors.textMuted),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

const _privacyPolicy = '''
1. INTRODUCTION

KOK ("we", "our", or "us") operates the KOK mobile application ("App"). This Privacy Policy explains how we collect, use, disclose, and protect your personal information when you use our App.

By using KOK, you agree to the collection and use of information as described in this policy.


2. INFORMATION WE COLLECT

a) Account Information
When you sign in with Google or Apple, we receive your email address and display name. We do not access your password.

b) Profile Information
You may voluntarily provide a nickname, nationality, and favorite K-pop artists/agencies. This information is displayed alongside your comments and chat messages.

c) User-Generated Content
Comments you post on articles and messages you send in artist chat rooms are stored on our servers.

d) Usage Data
We collect anonymized usage data such as articles viewed, features used, and app interactions to improve our service.

e) Advertising Data
We use Google AdMob to display ads. AdMob may collect device identifiers, IP address, and usage data for ad personalization. You can opt out of personalized ads in your device settings.


3. HOW WE USE YOUR INFORMATION

- To provide and maintain the App
- To display your profile on comments and chat messages
- To personalize your news feed based on your favorite tags
- To display relevant advertisements
- To monitor and prevent misuse of the App
- To communicate important updates


4. DATA STORAGE AND SECURITY

Your data is stored securely on Supabase servers. Chat messages are automatically deleted after 24 hours, with a maximum of 300 messages per artist board. We implement industry-standard security measures to protect your data, but no method of electronic storage is 100% secure.


5. THIRD-PARTY SERVICES

We use the following third-party services:
- Supabase (database and authentication)
- Google AdMob (advertising)
- Google Sign-In (authentication)
- Apple Sign-In (authentication)

Each service has its own privacy policy governing your data.


6. DATA RETENTION

- Account data: Retained until you delete your account
- Comments: Retained until you delete them or delete your account
- Chat messages: Automatically deleted after 24 hours
- AI-generated articles: Automatically deleted after 14 days


7. YOUR RIGHTS

You have the right to:
- Access your personal data
- Correct inaccurate data
- Delete your account and associated data
- Opt out of personalized advertising

To exercise these rights, contact us at heeya00910@gmail.com.


8. CHILDREN'S PRIVACY

KOK is not intended for children under 13. We do not knowingly collect personal information from children under 13.


9. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify users of significant changes through the App.


10. CONTACT US

If you have any questions about this Privacy Policy, please contact us at heeya00910@gmail.com.
''';

const _termsOfService = '''
1. ACCEPTANCE OF TERMS

By downloading, installing, or using the KOK application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.


2. DESCRIPTION OF SERVICE

KOK provides curated K-pop news content translated from Korean sources, along with summaries of Korean public opinion and reactions. The App also includes a Fandom Chart for voting and artist-specific chat rooms.


3. USER ACCOUNTS

a) You must sign in using Google or Apple to use the App.
b) You are responsible for maintaining the security of your account.
c) You must provide accurate information in your profile.
d) You may not create multiple accounts.


4. USER CONDUCT

You agree NOT to:
- Post content that is illegal, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, or otherwise objectionable
- Impersonate any person or entity
- Post spam, advertisements, or solicitations
- Attempt to interfere with the App's functionality
- Use automated systems to access the App
- Circumvent any content restrictions or ad requirements
- Share false or misleading information


5. USER-GENERATED CONTENT

a) You retain ownership of your comments and messages.
b) By posting content, you grant KOK a non-exclusive, worldwide license to display your content within the App.
c) We reserve the right to remove any content that violates these Terms or our Community Guidelines.
d) Chat messages are automatically deleted after 24 hours.


6. CONTENT AND INTELLECTUAL PROPERTY

a) AI-generated news summaries and translations are provided for informational purposes only.
b) Original news content belongs to its respective publishers. Links to original sources are provided.
c) KOK does not claim ownership of third-party content.
d) Artist symbols and visual elements in the App are original designs by KOK and do not represent official artist/agency branding.


7. ADVERTISING AND MONETIZATION

a) Free users receive 3 free article views per day.
b) Additional articles require watching 2 rewarded advertisements.
c) Users may earn bonus chart votes by watching advertisements.
d) Ad-blocking software may prevent proper App functionality.


8. FANDOM CHART

a) Each user may cast 1 free vote per day (resets at 00:00 KST).
b) Additional votes can be earned by watching 3 ads per vote.
c) The chart resets every Monday at 00:00 KST.
d) Any attempt to manipulate voting through bots or multiple accounts will result in account suspension.


9. DISCLAIMER

a) News content is generated by AI and may contain inaccuracies. We strive for accuracy but make no guarantees.
b) Korean public opinion summaries are based on available online sources and may not represent all viewpoints.
c) The App is provided "as is" without warranties of any kind.


10. LIMITATION OF LIABILITY

KOK shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.


11. TERMINATION

We reserve the right to suspend or terminate your account for violation of these Terms, at our sole discretion.


12. CHANGES TO TERMS

We may modify these Terms at any time. Continued use of the App after changes constitutes acceptance.


13. GOVERNING LAW

These Terms shall be governed by the laws of the Republic of Korea.


14. CONTACT

For questions about these Terms, contact us at heeya00910@gmail.com.
''';

const _communityGuidelines = '''
KOK is a community for K-pop fans to discover Korean perspectives and connect with other fans worldwide. To keep our community safe and welcoming, please follow these guidelines.


1. BE RESPECTFUL

- Treat all users with respect regardless of nationality, race, gender, sexual orientation, religion, or fandom.
- Healthy debate is welcome; personal attacks are not.
- Do not harass, bully, or intimidate other users.


2. NO HATE SPEECH

- Zero tolerance for hate speech, slurs, or discriminatory language.
- Do not promote violence or discrimination against any individual or group.
- Fandom rivalries should remain civil and respectful.


3. NO INAPPROPRIATE CONTENT

- Do not post sexually explicit, graphic, or violent content.
- Do not share private or personal information about artists or other users (doxxing).
- Do not post content that sexualizes minors in any way.


4. NO SPAM OR MANIPULATION

- Do not post repetitive messages, spam, or irrelevant promotions.
- Do not use bots or automated tools.
- Do not attempt to manipulate chart votes.


5. NO MISINFORMATION

- Do not spread false rumors or unverified information about artists.
- Do not fabricate news or reactions.
- If sharing opinions, clearly distinguish them from facts.


6. PROTECT PRIVACY

- Do not share other users' personal information.
- Do not share private contact details of artists or industry personnel.
- Respect the privacy of all individuals.


7. REPORTING VIOLATIONS

If you see content that violates these guidelines:
- Use the report button on the message/comment.
- Our moderation team will review reports and take appropriate action.

Actions may include:
- Warning
- Content removal
- Temporary suspension
- Permanent account ban


8. ARTIST CHAT ROOMS

Chat rooms are designed for fans to connect. Additional rules:
- Stay on topic for the relevant artist.
- Messages are automatically deleted after 24 hours.
- Maximum 300 messages per artist board to maintain performance.
- Excessive negativity or anti-fan behavior will result in removal.


9. ADMIN DECISIONS

KOK administrators have final authority on content moderation decisions. Repeated violations will result in escalating consequences.


10. CONTACT

To report serious violations or appeal a moderation decision, contact heeya00910@gmail.com.
''';
