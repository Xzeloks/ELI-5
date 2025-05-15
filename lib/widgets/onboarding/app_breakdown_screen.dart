import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // For AppColors

const String hasSeenAppBreakdownKey = 'hasSeenAppBreakdown';

class AppBreakdownScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const AppBreakdownScreen({super.key, required this.onFinished});

  @override
  State<AppBreakdownScreen> createState() => _AppBreakdownScreenState();
}

class _AppBreakdownScreenState extends State<AppBreakdownScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  final int _numPages = 3; // Updated number of pages

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (_dontShowAgain) {
      await prefs.setBool(hasSeenAppBreakdownKey, true);
    }
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: isActive ? 10.0 : 8.0,
      width: isActive ? 12.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? AppColors.kopyaPurple : AppColors.textDisabledDark,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );
  }

  List<Widget> _buildPageIndicators() {
    List<Widget> list = [];
    for (int i = 0; i < _numPages; i++) { // Use _numPages
      list.add(i == _currentPage ? _buildPageIndicator(true) : _buildPageIndicator(false));
    }
    return list;
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle, {bool isPurpleIcon = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26.0, color: isPurpleIcon ? AppColors.kopyaPurple : AppColors.brightBlue),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHighEmphasisDark,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textMediumEmphasisDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {double topPadding = 16.0}) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textHighEmphasisDark,
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, {bool hasTail = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 12.0, bottom: 20.0, left: 8.0, right: 20.0),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.inputFillDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
          bottomLeft: Radius.circular(4.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 17,
          color: AppColors.textMediumEmphasisDark,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildPage({required List<Widget> children, required BuildContext context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints viewportConstraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: children,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.kopyaPurple.withOpacity(0.5),
            blurRadius: 12.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Card(
        elevation: 0, // Handled by the Container's boxShadow
        color: AppColors.inputFillDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Page 1: Welcome
      _buildPage(
        context: context,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlowingCard([
                Text(
                  'Welcome to ELI5!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasisDark),
                ),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'ELI5 makes complex topics easy. Ask questions, share links (including YouTube videos!), or use images to get simple explanations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      color: AppColors.textMediumEmphasisDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ]),
            ],
          )
        ],
      ),
      // Page 2: Input Methods
      _buildPage(
        context: context,
        children: [
          _buildSectionTitle('Your Input, Simplified'),
          _buildInfoRow(FeatherIcons.type, 'Type Your Question', 'Got a complex topic or a quick question? Just type it in.'),
          _buildInfoRow(FeatherIcons.link2, 'Paste a Link (inc. YouTube!)', 'Share a web article or even a YouTube video URL, and we\'ll summarize it for you ELI5 style!'),
          _buildInfoRow(FeatherIcons.image, 'Use Text from Image/Device', 'Extract text from images or directly from content on your device.'),
        ],
      ),
      // Page 3: Explanations, Navigation, and Finish Up
      _buildPage(
        context: context,
        children: [
          _buildSectionTitle('Get Answers & Find Your Way'),
          _buildInfoRow(FeatherIcons.zap, 'Get Simple Explanations', 'Our AI will break down complex information into easy-to-understand explanations.'),
          _buildInfoRow(FeatherIcons.home, 'Main Hub', 'This is where you\'ll start your learning journey and input your queries.'),
          _buildInfoRow(FeatherIcons.list, 'History', 'Revisit all your past explanations and summaries anytime.'),
          _buildInfoRow(FeatherIcons.settings, 'Settings', 'Customize your app experience and manage preferences.'),
          
          Padding(
            padding: const EdgeInsets.only(top: 30.0),
            child: const Icon(FeatherIcons.checkCircle, size: 50, color: AppColors.kopyaPurple),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re All Set!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasisDark),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
            child: CheckboxListTile(
              title: Text("Don't show this again", style: GoogleFonts.poppins(color: AppColors.textMediumEmphasisDark)),
              value: _dontShowAgain,
              onChanged: (bool? value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              activeColor: AppColors.kopyaPurple,
              checkColor: AppColors.textOnPrimaryDark,
              tileColor: AppColors.inputFillDark,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(color: AppColors.dividerDark),
              ),
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _numPages, // Use _numPages
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  return pages[index];
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage == 0
                      ? const SizedBox(width: 80)
                      : TextButton(
                          onPressed: () {
                            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                          },
                          child: Text('Back', style: GoogleFonts.poppins(color: AppColors.textMediumEmphasisDark, fontSize: 16)),
                        ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildPageIndicators(),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (_currentPage < _numPages - 1) { // Use _numPages
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                      } else {
                        await _markAsSeen();
                        widget.onFinished();
                      }
                    },
                    child: Text(
                      _currentPage == _numPages - 1 ? 'Let\'s Go!' : 'Next', // Use _numPages
                      style: GoogleFonts.poppins(color: AppColors.kopyaPurple, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 