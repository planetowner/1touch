import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

// --- Widget 1: The Main Page Betting Dashboard ---
class MatchBettingSection extends StatelessWidget {
  final int userBalance;
  final VoidCallback onPlaceBet;

  const MatchBettingSection({
    super.key,
    required this.userBalance,
    required this.onPlaceBet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Visual stats header
          const MatchStatsHeader(),

          const SizedBox(height: 24),

          // Points Balance
          Text(
            "You’ve got $userBalance pts!",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const SizedBox(height: 24),

          // Place Bet Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPlaceBet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "PLACE A BET",
                style: TextStyle(
                  color: Color(0xFF090A0A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- Widget 2: The Modal Flow ---
class BettingFlowModal extends StatefulWidget {
  final int userBalance;
  const BettingFlowModal({super.key, required this.userBalance});

  @override
  State<BettingFlowModal> createState() => _BettingFlowModalState();
}

enum BetStep { selection, amount, success }

class _BettingFlowModalState extends State<BettingFlowModal> {
  BetStep _currentStep = BetStep.selection;
  int? _selectedOptionIndex; // 0: FCB, 1: Draw, 2: GIR
  int _wagerAmount = 120;

  void _nextStep() {
    if (_currentStep == BetStep.selection && _selectedOptionIndex != null) {
      setState(() => _currentStep = BetStep.amount);
    } else if (_currentStep == BetStep.amount) {
      setState(() => _currentStep = BetStep.success);
    } else if (_currentStep == BetStep.success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF272828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal Header (Title + Close Button)
          if (_currentStep != BetStep.success)
            Stack(
              children: [
                const Center(child: Text("Bets", style: Heading3.style)),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                )
              ],
            ),

          if (_currentStep != BetStep.success)
            const SizedBox(height: 24),

          // If Success, show success view.
          // Otherwise, show the Full Stats Header + The current form step.
          if (_currentStep == BetStep.success)
            _buildSuccessView()
          else
            Column(
              children: [
                // PERSISTENT HEADER: This stays for both Selection and Amount steps
                const MatchStatsHeader(),

                const SizedBox(height: 24),

                // Form Content
                if (_currentStep == BetStep.selection) _buildSelectionStep(),
                if (_currentStep == BetStep.amount) _buildAmountStep(),

                const SizedBox(height: 24),

                // Main Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_currentStep == BetStep.selection && _selectedOptionIndex == null)
                        ? null
                        : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white24,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentStep == BetStep.success ? "DONE" : "CONTINUE",
                      style: const TextStyle(
                        color: Color(0xFF090A0A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionStep() {
    return Column(
      children: [
        _buildRadioOption(0, "FCB Win", "+120 pts", "TeamLogos/Barcelona.png"),
        const SizedBox(height: 12),
        _buildRadioOption(1, "Draw", "+80 pts", "TeamLogos/Barcelona.png", isDraw: true),
        const SizedBox(height: 12),
        _buildRadioOption(2, "BBB Win", "+320 pts", "TeamLogos/Girona.png"),
      ],
    );
  }

  Widget _buildRadioOption(int index, String title, String subtitle, String iconPath, {bool isDraw = false}) {
    bool isSelected = _selectedOptionIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedOptionIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
        ),
        child: Row(
          children: [
            if (isDraw)
            // Stacked icons for Draw
              SizedBox(width: 40, height: 40, child: Stack(
                children: [
                  Align(alignment: Alignment.topLeft, child: Image.asset("TeamLogos/Barcelona.png", width: 28)),
                  Align(alignment: Alignment.bottomRight, child: Image.asset("TeamLogos/Girona.png", width: 28)),
                ],
              ))
            else
              Image.asset(iconPath, width: 40, height: 40),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            // Radio Circle
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.white : Colors.grey, width: 2),
                  color: Colors.transparent
              ),
              child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))) : null,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAmountStep() {
    return Column(
      children: [
        // The Point Box Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$_wagerAmount", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6.0),
                    child: Text("pts", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildCircleButton(Icons.remove, () => setState(() => _wagerAmount = (_wagerAmount - 10).clamp(10, widget.userBalance))),
                  const SizedBox(width: 16),
                  _buildCircleButton(Icons.add, () => setState(() => _wagerAmount = (_wagerAmount + 10).clamp(10, widget.userBalance))),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Text is now OUTSIDE the box
        Text("You’ve got ${widget.userBalance} pts!", style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // --- Success View ---
  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),

        const Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
        const SizedBox(height: 24),

        const Text("Bet Submitted!", style: Heading3.style),

        const SizedBox(height: 16),
        const Text(
          "Check back after the final whistle for the result.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 48),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "DONE",
              style: TextStyle(
                color: Color(0xFF090A0A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        )
      ],
    );
  }
}

// --- Shared Component: The Logos, W/D/L Stats, and Percentage Bar ---
class MatchStatsHeader extends StatelessWidget {
  const MatchStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Logos and W/D/L Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeamLogo('FCB', "TeamLogos/Barcelona.png"),

            // Odds Stats
            Row(
              children: [
                _buildOddsColumn("###", "W"),
                const SizedBox(width: 8),
                _buildOddsColumn("###", "D"),
                const SizedBox(width: 8),
                _buildOddsColumn("###", "L"),
              ],
            ),

            _buildTeamLogo('GIR', "TeamLogos/Girona.png"),
          ],
        ),

        const SizedBox(height: 24),

        // 2. Percentage Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  flex: 60,
                  child: Container(
                    color: const Color(0xFFFF5757), // Red
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: const Text("60%", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Container(color: const Color(0xFFFFAAAA)), // Pinkish
                ),
                Expanded(
                  flex: 30,
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    child: const Text("30%", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 3. Text Descriptions under bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("FCB Win\n(+120)", style: Body2.style),
            Text("Draw\n(+80)", style: Body2.style, textAlign: TextAlign.center),
            Text("GIR Win\n(+320)", style: Body2.style, textAlign: TextAlign.right),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamLogo(String name, String assetPath) {
    return Column(
      children: [
        Image.asset(assetPath, width: 48, height: 48),
        const SizedBox(height: 4),
        Text(name, style: Body1_b.style),
      ],
    );
  }

  Widget _buildOddsColumn(String value, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}