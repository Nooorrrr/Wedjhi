import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Custom text field for authentication screens
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool isLastField;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;

  const AuthTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.isLastField = false,
    this.focusNode,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppPadding.gap),
      child: TextFormField(
        controller: controller,
        decoration: AppInputDecorations.textField(
          labelText: labelText,
          prefixIcon: prefixIcon,
          hintText: hintText,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        focusNode: focusNode,
        textInputAction:
            isLastField ? TextInputAction.done : TextInputAction.next,
        onEditingComplete: onEditingComplete ??
            () {
              if (!isLastField) {
                FocusScope.of(context).nextFocus();
              } else {
                FocusScope.of(context).unfocus();
              }
            },
        style: AppTextStyles.body,
      ),
    );
  }
}

/// Email field with validation
class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isLastField;
  final VoidCallback? onEditingComplete;

  const EmailField({
    Key? key,
    required this.controller,
    this.focusNode,
    this.isLastField = false,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: controller,
      labelText: 'Email',
      hintText: 'Enter your email address',
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      isLastField: isLastField,
      focusNode: focusNode,
      onEditingComplete: onEditingComplete,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
}

/// Password field with validation
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final bool isLastField;
  final VoidCallback? onEditingComplete;

  const PasswordField({
    Key? key,
    required this.controller,
    this.labelText = 'Password',
    this.focusNode,
    this.isLastField = false,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppPadding.gap),
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: 'Enter your password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: AppColors.primary.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          filled: true,
          fillColor: Colors.white,
        ),
        obscureText: _obscureText,
        keyboardType: TextInputType.visiblePassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
        focusNode: widget.focusNode,
        textInputAction:
            widget.isLastField ? TextInputAction.done : TextInputAction.next,
        onEditingComplete: widget.onEditingComplete ??
            () {
              if (!widget.isLastField) {
                FocusScope.of(context).nextFocus();
              } else {
                FocusScope.of(context).unfocus();
              }
            },
        style: AppTextStyles.body,
      ),
    );
  }
}

/// Confirm password field with validation
class ConfirmPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;

  const ConfirmPasswordField({
    Key? key,
    required this.controller,
    required this.passwordController,
    this.focusNode,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  _ConfirmPasswordFieldState createState() => _ConfirmPasswordFieldState();
}

class _ConfirmPasswordFieldState extends State<ConfirmPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppPadding.gap),
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          hintText: 'Re-enter your password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: AppColors.primary.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          filled: true,
          fillColor: Colors.white,
        ),
        obscureText: _obscureText,
        keyboardType: TextInputType.visiblePassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please confirm your password';
          }
          if (value != widget.passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
        focusNode: widget.focusNode,
        textInputAction: TextInputAction.done,
        onEditingComplete: widget.onEditingComplete ??
            () {
              FocusScope.of(context).unfocus();
            },
        style: AppTextStyles.body,
      ),
    );
  }
}
