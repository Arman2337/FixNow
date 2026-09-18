import 'package:flutter/material.dart';
import 'package:fixnow_mobile/features/guarantees/data/guarantee_repository.dart';

class SubmitClaimScreen extends StatefulWidget {
  final String bookingId;
  final GuaranteeRepository repository;

  const SubmitClaimScreen({
    Key? key,
    required this.bookingId,
    required this.repository,
  }) : super(key: key);

  @override
  _SubmitClaimScreenState createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitClaim() async {
    if (_descriptionController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.submitClaim(
        bookingId: widget.bookingId,
        description: _descriptionController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guarantee Claim submitted successfully.')),
        );
        Navigator.of(context).pop(); // Go back to booking screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Guarantee Claim')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Describe the issue with your completed service.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Please provide details about what went wrong...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitClaim,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Claim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
