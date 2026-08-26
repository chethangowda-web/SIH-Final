import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import 'sih_demo_mode_dialog.dart';

class JudgeViewDialog extends StatefulWidget {
  const JudgeViewDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const JudgeViewDialog(),
    );
  }

  @override
  State<JudgeViewDialog> createState() => _JudgeViewDialogState();
}

class _JudgeViewDialogState extends State<JudgeViewDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  SihJudgeDefenseData? _defenseData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDefenseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDefenseData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchJudgeDefenseView();
      if (mounted) {
        setState(() {
          _defenseData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: size.width > 1200 ? 1150 : size.width * 0.95,
        height: size.height * 0.90,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          children: [
            _buildHeader(theme),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEcosystemTab(),
                            _buildValueChainTab(),
                            _buildFormulationsTab(),
                            _buildFaqTab(),
                          ],
                        ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 10,
                )
              ],
            ),
            child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SIH 2026 Jury Technical Defense & Architecture Audit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                      ),
                      child: const Text(
                        'JUDGE VIEW',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _defenseData?.projectPositioning ?? 'Interoperable Pre-Dispatch Decision Intelligence Layer for Targeted PDS',
                  style: TextStyle(
                    color: Colors.blueGrey[300],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey),
            tooltip: 'Close Defense View',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFF59E0B),
        indicatorWeight: 3,
        labelColor: const Color(0xFFF59E0B),
        unselectedLabelColor: Colors.blueGrey[300],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.account_tree_outlined, size: 18),
            text: '1. Ecosystem Demarcation',
          ),
          Tab(
            icon: Icon(Icons.linear_scale_rounded, size: 18),
            text: '2. Closed-Loop Value Chain',
          ),
          Tab(
            icon: Icon(Icons.functions_rounded, size: 18),
            text: '3. Mathematical Formulations',
          ),
          Tab(
            icon: Icon(Icons.shield_outlined, size: 18),
            text: '4. Jury FAQ Defense Matrix',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Failed to load Defense Dossier',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDefenseData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: ECOSYSTEM DEMARCATION ("What Exists" vs "What We Add")
  // -------------------------------------------------------------
  Widget _buildEcosystemTab() {
    if (_defenseData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Core USP Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E3A8A).withValues(alpha: 0.7), const Color(0xFF0F172A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF60A5FA), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'CORE ARCHITECTURAL POSITIONING: ',
                          style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextSpan(
                          text: 'We DO NOT replace ePoS, Annavitran, or SMART-PDS. We introduce an interoperable Decision Intelligence Layer operating 3–7 days before dispatch.',
                          style: TextStyle(color: Colors.blueGrey[100], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Two-column side-by-side comparison
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final colWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 20) / 2;

              final whatExistsWidget = Container(
                width: colWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.cyanAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'WHAT EXISTS (National Baseline)',
                            style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _defenseData!.whatExistsDescription,
                      style: TextStyle(color: Colors.blueGrey[200], fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    ..._defenseData!.whatExistsPillars.map((p) => _buildPillarCard(p)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Inherent Baseline Gaps Identified:',
                                style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ..._defenseData!.whatExistsGaps.map(
                            (g) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Colors.orangeAccent)),
                                  Expanded(
                                    child: Text(g, style: TextStyle(color: Colors.grey[300], fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final whatWeAddWidget = Container(
                width: colWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'WHAT WE ADD (Novel Intelligence Layer)',
                            style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _defenseData!.whatWeAddDescription,
                      style: TextStyle(color: Colors.blueGrey[200], fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    ..._defenseData!.whatWeAddInnovations.map((inn) => _buildInnovationCard(inn)),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    whatExistsWidget,
                    const SizedBox(height: 20),
                    whatWeAddWidget,
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    whatExistsWidget,
                    const SizedBox(width: 20),
                    whatWeAddWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard(WhatExistsPillar p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.coverage,
                  style: TextStyle(color: Colors.cyan[200], fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            p.role,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInnovationCard(WhatWeAddInnovation inn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inn.stage,
            style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            inn.description,
            style: TextStyle(color: Colors.grey[300], fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: CLOSED-LOOP VALUE CHAIN MATRIX
  // -------------------------------------------------------------
  Widget _buildValueChainTab() {
    if (_defenseData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full 9-Stage Operational Pipeline — End-to-End Audit Trail',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Every stage produces an explicit deterministic output, preventing black-box execution and ensuring strict statutory compliance.',
                        style: TextStyle(color: Colors.blueGrey[300], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._defenseData!.valueChainMatrix.map((step) => _buildChainMatrixRow(step)),
        ],
      ),
    );
  }

  Widget _buildChainMatrixRow(ValueChainMatrixStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${step.step}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Actor: ${step.actor}',
                    style: TextStyle(color: Colors.cyan[300], fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INPUT VECTOR:', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(step.input, style: TextStyle(color: Colors.blueGrey[200], fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DETERMINISTIC OUTPUT:', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                Text(step.output, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: MATHEMATICAL FORMULATIONS & CONSTRAINTS
  // -------------------------------------------------------------
  Widget _buildFormulationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormulaCard(
            title: '1. Multi-Factor Explainable Demand Forecast (Rice & Wheat)',
            formula: r'D̂ = (1 - α) · H + α · I',
            explanation: 'Where H is the 6-cycle recency-weighted baseline average, I is forward-looking intent demand, and α = w · C (intent weight w=0.30 scaled by confidence score C). Additionally adjusts for 3-cycle momentum trend, calendar festival multiplier, and stockout distortion correction.',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 14),
          _buildFormulaCard(
            title: '2. Dynamic Pre-Dispatch Quantity Calculus',
            formula: r'Dispatch = max(0, D̂ - S + B)',
            explanation: 'Where D̂ is predicted demand, S is current available FPS stock, and B is the dynamic safety buffer calculated from lead time (0.50), stock-out risk index (0.35), storage capacity ceiling, and consumption volatility.',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 14),
          _buildFormulaCard(
            title: '3. Multi-Candidate Corridor Dispatch Optimization Penalty',
            formula: r'Minimize Φ = S_cost + S_stockout + S_excess + S_delay',
            explanation: 'Scores candidate fleet carriers & departure windows. S_cost = Total INR / 400, S_stockout = Risk · 50, S_excess = Excess Index · 1.5, S_delay = (Duration / 30 mins) · Traffic Multiplier. Delivery sequence ordered via Nearest-Neighbor Traveling Salesperson (TSP) heuristic.',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 14),
          _buildFormulaCard(
            title: '4. Cryptographic Manifest Freeze & Verification Seal',
            formula: r'Seal = SHA-256(ManifestID || CycleID || TruckID || PayloadKG || Timestamp)',
            explanation: 'Generates immutable SHA-256 hash seal upon District Supply Officer (DSO) approval. Modifications in LOCKED status are strictly blocked under NFSA statutory audit rules, requiring explicit versioning (v1.0 -> v1.1).',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required String formula,
    required String explanation,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              formula,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: TextStyle(color: Colors.blueGrey[200], fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: JURY FAQ DEFENSE MATRIX
  // -------------------------------------------------------------
  Widget _buildFaqTab() {
    if (_defenseData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Answers to Common Jury Scrutiny Questions',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Addressing technical feasibility, interoperability with SMART-PDS, rural connectivity, and statutory NFSA compliance.',
                        style: TextStyle(color: Colors.blueGrey[300], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._defenseData!.judgeFaqDefense.map((faq) => _buildFaqCard(faq)),
        ],
      ),
    );
  }

  Widget _buildFaqCard(JudgeFaqItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: const Color(0xFFF59E0B),
        collapsedIconColor: Colors.grey,
        title: Text(
          faq.question,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    faq.defense,
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                'Prototype Simulation Notice: Pre-dispatch synthetic model calibrated for SIH 2026.',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  SihDemoModeDialog.show(context);
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                label: const Text('★ Run 14-Step Demo Scenario'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Close Defense View', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
