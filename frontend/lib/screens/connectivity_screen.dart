import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/health_model.dart';
import '../services/api_service.dart';

class ConnectivityScreen extends StatefulWidget {
  final ApiService? apiService;

  const ConnectivityScreen({super.key, this.apiService});

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  late final ApiService _apiService;
  final TextEditingController _urlController =
      TextEditingController(text: AppConstants.healthEndpoint);

  HealthModel? _healthData;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _performHealthCheck();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _performHealthCheck() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data =
          await _apiService.checkHealth(customUrl: _urlController.text.trim());
      if (mounted) {
        setState(() {
          _healthData = data;
          _isLoading = false;
          _lastChecked = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _lastChecked = DateTime.now();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: _buildGovAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSystemBanner(),
                const SizedBox(height: 20),
                _buildConnectivityCard(),
                const SizedBox(height: 24),
                _buildWorkflowVisualizer(),
                const SizedBox(height: 24),
                _buildFooterNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGovAppBar() {
    return AppBar(
      backgroundColor: AppConstants.primaryNavy,
      elevation: 2,
      titleSpacing: 16,
      toolbarHeight: 70,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Department of Food & Public Distribution • Decision Support Overlay',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _healthData != null && _errorMessage == null
                        ? AppConstants.successGreen
                        : (_isLoading
                            ? AppConstants.accentAmber
                            : AppConstants.dangerRed),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _healthData != null && _errorMessage == null
                      ? 'ONLINE'
                      : (_isLoading ? 'PINGING' : 'READY'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppConstants.secondaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hub,
              color: AppConstants.secondaryNavy,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'PDS DemandSync Architecture Foundation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'DEMO V1',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  AppConstants.appSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppConstants.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(color: AppConstants.borderLight),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors,
                  size: 18,
                  color: AppConstants.primaryNavy,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'End-to-End API Health & Diagnostics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_lastChecked != null)
                  Text(
                    'Last tested: ${_lastChecked!.hour.toString().padLeft(2, '0')}:${_lastChecked!.minute.toString().padLeft(2, '0')}:${_lastChecked!.second.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppConstants.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // URL input + Test Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          labelText: 'Health-Check Endpoint URL',
                          labelStyle: const TextStyle(fontSize: 11.5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: AppConstants.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: AppConstants.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: AppConstants.accentBlue, width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.link, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _performHealthCheck,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(_isLoading ? 'Pinging...' : 'Ping API'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Diagnostic Result State
                if (_isLoading)
                  _buildLoadingState()
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_healthData != null)
                  _buildSuccessState(_healthData!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        children: const [
          CircularProgressIndicator(
            color: AppConstants.secondaryNavy,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 12),
          Text(
            'Dispatching HTTP GET request to FastAPI backend...',
            style: TextStyle(
              fontSize: 12.5,
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline,
                  color: AppConstants.dangerRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Connection Standby / Unreachable',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.dangerRed,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Unable to connect to backend server.',
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ensure the FastAPI backend is running via:\n`uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`',
            style: TextStyle(
              color: Color(0xFF7F1D1D),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(HealthModel data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppConstants.successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Flutter ↔ FastAPI ↔ SQLite Connectivity Verified',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed,
                        size: 13, color: AppConstants.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${data.latencyMs} ms',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFDCFCE7)),
          const SizedBox(height: 14),
          // Diagnostic Matrix Grid
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildMetricTile(
                'Backend API Status',
                data.status.toUpperCase(),
                Icons.check_circle_outline,
                AppConstants.successGreen,
              ),
              _buildMetricTile(
                'SQLite Relational Engine',
                '${data.databaseStatus.toUpperCase()} (9 Tables)',
                Icons.storage_outlined,
                AppConstants.secondaryNavy,
              ),
              _buildMetricTile(
                'Operational Pilot District',
                data.district,
                Icons.location_city_outlined,
                AppConstants.accentBlue,
              ),
              _buildMetricTile(
                'Active Cycle',
                data.activeCycle,
                Icons.calendar_today_outlined,
                AppConstants.accentAmber,
              ),
              _buildMetricTile(
                'Fair Price Shops',
                '${data.fpsCount} Urban Fair Price Shops',
                Icons.storefront_outlined,
                AppConstants.primaryNavy,
              ),
              _buildMetricTile(
                'Registered Beneficiaries',
                '${data.beneficiariesCount} Ration Cards',
                Icons.people_outline,
                AppConstants.secondaryNavy,
              ),
              _buildMetricTile(
                'Build Version',
                data.version,
                Icons.info_outline,
                AppConstants.textSecondary,
              ),
              _buildMetricTile(
                'Server Timestamp',
                data.serverTime,
                Icons.access_time,
                AppConstants.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppConstants.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowVisualizer() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.alt_route,
                size: 18,
                color: AppConstants.primaryNavy,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PDS DemandSync Closed-Loop Decision Pipeline',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Core 8-stage operational workflow for dynamic pre-dispatch public distribution forecasting:',
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppConstants.workflowSteps.map((step) {
                  return Container(
                    width: constraints.maxWidth > 700
                        ? (constraints.maxWidth - 30) / 4
                        : (constraints.maxWidth - 10) / 2,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppConstants.secondaryNavy,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                step['num']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                step['title']!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          step['desc']!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppConstants.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: const [
          Icon(Icons.gavel, size: 15, color: AppConstants.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppConstants.demoNotice,
              style: TextStyle(
                fontSize: 11,
                color: AppConstants.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
