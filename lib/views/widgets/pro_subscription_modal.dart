import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/in_app_purchase_service.dart';

class ProSubscriptionModal extends StatefulWidget {
  const ProSubscriptionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProSubscriptionModal(),
    );
  }

  @override
  State<ProSubscriptionModal> createState() => _ProSubscriptionModalState();
}

class _ProSubscriptionModalState extends State<ProSubscriptionModal> {
  // 0: Yearly (Recommended / Best Value), 1: Monthly
  int _selectedPlanIndex = 0;
  bool _isProcessing = false;

  final InAppPurchaseService _iapService = InAppPurchaseService();

  @override
  void initState() {
    super.initState();
    _iapService.loadProducts();
  }

  ProductDetails? get _yearlyProduct {
    try {
      return _iapService.products.firstWhere(
        (p) => p.id == InAppPurchaseService.yearlySubscriptionId,
      );
    } catch (_) {
      return null;
    }
  }

  ProductDetails? get _monthlyProduct {
    try {
      return _iapService.products.firstWhere(
        (p) => p.id == InAppPurchaseService.monthlySubscriptionId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleSubscribe() async {
    final selectedProduct = _selectedPlanIndex == 0 ? _yearlyProduct : _monthlyProduct;

    if (selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription items are loading from Google Play...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final success = await _iapService.buySubscription(selectedProduct);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to initiate purchase. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header Badge & Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8F00), Color(0xFFFF6F00)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'PDF PRO SUBSCRIPTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unlock Complete PDF Power',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Remove all ads, unlock ultra compression & 4K quality export',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6E6E6E)),
              ),

              const SizedBox(height: 20),

              // Feature Highlights List
              _buildBenefitRow(Icons.block_rounded, '100% Ad-Free Experience (No banners, no popup ads)'),
              _buildBenefitRow(Icons.compress_rounded, 'Ultra Max Compression (Reduce size up to 85%)'),
              _buildBenefitRow(Icons.high_quality_rounded, 'Ultra HD 4K PDF to Image Export (300 DPI)'),
              _buildBenefitRow(Icons.bolt_rounded, 'Unlimited Document Processing & Priority Speed'),

              const SizedBox(height: 20),

              // Plan 1: Yearly Subscription (Recommended)
              _buildPlanCard(
                index: 0,
                title: 'Yearly Plan',
                badgeText: 'BEST VALUE • SAVE 60%',
                price: _yearlyProduct?.price ?? '₹999 / year',
                subtitle: 'Includes 7-day free trial, cancel anytime',
              ),

              const SizedBox(height: 10),

              // Plan 2: Monthly Subscription
              _buildPlanCard(
                index: 1,
                title: 'Monthly Plan',
                badgeText: null,
                price: _monthlyProduct?.price ?? '₹199 / month',
                subtitle: 'Flexible monthly billing, cancel anytime',
              ),

              const SizedBox(height: 20),

              // Subscribe Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5252A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _isProcessing ? null : _handleSubscribe,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _selectedPlanIndex == 0 ? 'Start Yearly Subscription' : 'Start Monthly Subscription',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Restore Purchases & Terms
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      await _iapService.restorePurchases();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking previous purchases...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                    ),
                  ),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5252A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: const Color(0xFFE5252A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String? badgeText,
    required String price,
    required String subtitle,
  }) {
    final isSelected = _selectedPlanIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedPlanIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1F1) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5252A) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFE5252A) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8F00),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
