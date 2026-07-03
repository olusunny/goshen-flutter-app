import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/LoginScreen.dart';
import '../providers/AppStateManager.dart';
import '../utils/ApiUrl.dart';
import '../utils/my_colors.dart';

class SuggestionScreen extends StatefulWidget {
  static const routeName = '/suggestions';

  const SuggestionScreen({Key? key}) : super(key: key);

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    if (user.activated == 1) {
      _showMessage('Please verify your account before sending a suggestion.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await Dio().post(
        ApiUrl.SUBMIT_SUGGESTION,
        data: jsonEncode({
          'data': {
            'api_token': user.apiToken,
            'email': user.email,
            'subject': _subjectController.text.trim(),
            'message': _messageController.text.trim(),
            'device': 'Android',
          }
        }),
      );
      final data = response.data is Map
          ? response.data
          : jsonDecode(response.data.toString()) as Map;
      if (data['status'] == 'ok') {
        _subjectController.clear();
        _messageController.clear();
        _showMessage('Thank you. Your suggestion has been sent.');
      } else {
        _showMessage(
            data['message']?.toString() ?? 'Unable to send suggestion.');
      }
    } catch (error) {
      _showMessage('Unable to send suggestion. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Share a suggestion',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            user == null
                ? 'Please sign in to send a suggestion to the church admin team.'
                : 'Use this suggestion box for church matters, ministry ideas, app feedback, welfare concerns, event suggestions, or anything helpful you want the church admin team to review.',
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 160,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Suggestion',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 7,
                  maxLines: 10,
                  validator: (value) {
                    if ((value ?? '').trim().length < 5) {
                      return 'Please enter a suggestion.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label:
                        Text(_isSubmitting ? 'Sending...' : 'Send suggestion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primary,
                      foregroundColor: Colors.white,
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
}
