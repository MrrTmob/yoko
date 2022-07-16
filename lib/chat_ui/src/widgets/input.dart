import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:yoko/keyboard/src/widgets/math_field.dart';

import '../../../keyboard/math_keyboard.dart';
import '../models/send_button_visibility_mode.dart';
import 'attachment_button.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';
import 'input_text_field_controller.dart';
import 'send_button.dart';

class NewLineIntent extends Intent {
  const NewLineIntent();
}

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

/// A class that represents bottom bar widget with a text field, attachment and
/// send buttons inside. By default hides send button when text field is empty.
class Input extends StatefulWidget {
  /// Creates [Input] widget.
  const Input({
    super.key,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    required this.onSendPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    required this.sendButtonVisibilityMode,
    this.textEditingController,
  });

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// See [AttachmentButton.onPressed].
  final void Function()? onAttachmentPressed;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  final void Function(types.PartialText) onSendPressed;

  /// Will be called whenever the text inside [TextField] changes.
  final void Function(String)? onTextChanged;

  /// Will be called on [TextField] tap.
  final void Function()? onTextFieldTap;

  /// Controls the visibility behavior of the [SendButton] based on the
  /// [TextField] state inside the [Input] widget.
  /// Defaults to [SendButtonVisibilityMode.editing].
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  /// Custom [TextEditingController]. If not provided, defaults to the
  /// [InputTextFieldController], which extends [TextEditingController] and has
  /// additional fatures like markdown support. If you want to keep additional
  /// features but still need some methods from the default [TextEditingController],
  /// you can create your own [InputTextFieldController] (imported from this lib)
  /// and pass it here.
  final TextEditingController? textEditingController;

  @override
  State<Input> createState() => _InputState();
}

/// [Input] widget state.
class _InputState extends State<Input> {
  final _inputFocusNode = FocusNode();
  bool _sendButtonVisible = false;
  late TextEditingController _textController;
  final _mathController = MathFieldEditingController();

  @override
  void initState() {
    super.initState();
    _mathController.addListener(_handleTextControllerChange);
    _textController =
        widget.textEditingController ?? InputTextFieldController();
    _handleSendButtonVisibilityModeChange();
  }

  @override
  void didUpdateWidget(covariant Input oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sendButtonVisibilityMode != oldWidget.sendButtonVisibilityMode) {
      _handleSendButtonVisibilityModeChange();
    }
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    _mathController.dispose();
    super.dispose();
  }

  double _height = 0;
  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return WillPopScope(
      onWillPop: () async {
        if (_height != 0) {
          _inputFocusNode.unfocus();
          setState(() {
            _height = 0;
          });
          return false;
        } else {
          return true;
        }
      },
      child: GestureDetector(
        //onTap: () => _inputFocusNode.requestFocus(),
        onTap: () {
          _inputFocusNode.requestFocus();
          setState(() {
            _height = 300;
          });
        },
        child: isAndroid || isIOS
            ? _inputBuilder()
            : Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.enter):
                      const SendMessageIntent(),
                  LogicalKeySet(
                          LogicalKeyboardKey.enter, LogicalKeyboardKey.alt):
                      const NewLineIntent(),
                  LogicalKeySet(
                    LogicalKeyboardKey.enter,
                    LogicalKeyboardKey.shift,
                  ): const NewLineIntent(),
                },
                child: Actions(
                  actions: {
                    SendMessageIntent: CallbackAction<SendMessageIntent>(
                      onInvoke: (SendMessageIntent intent) =>
                          _handleSendPressed(),
                    ),
                    NewLineIntent: CallbackAction<NewLineIntent>(
                      onInvoke: (NewLineIntent intent) => _handleNewLine(),
                    ),
                  },
                  child: _inputBuilder(),
                ),
              ),
      ),
    );
  }

  void _handleNewLine() {
    final newValue = '${_textController.text}\r\n';
    _textController.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: newValue.length),
      ),
    );
  }

  void _handleSendButtonVisibilityModeChange() {
    _textController.removeListener(_handleTextControllerChange);
    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.hidden) {
      _sendButtonVisible = false;
    } else if (widget.sendButtonVisibilityMode ==
        SendButtonVisibilityMode.editing) {
      _sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible = true;
    }
  }

  void _handleSendPressed() {
    //final trimmedText = _textController.text.trim();
    final trimmedText = _mathController.currentEditingValue().trim();
    if (trimmedText != '') {
      final partialText = types.PartialText(text: trimmedText);
      widget.onSendPressed(partialText);
      _textController.clear();
      _mathController.clear();
    }
    
  }

  void _handleTextControllerChange() {
    setState(() {
      _sendButtonVisible = !_mathController.isEmpty;
      // _sendButtonVisible = _textController.text.trim() != '';
    });
  }

  Widget _inputBuilder() {
    final query = MediaQuery.of(context);
    final buttonPadding = InheritedChatTheme.of(context)
        .theme
        .inputPadding
        .copyWith(left: 16, right: 16);
    final safeAreaInsets = kIsWeb
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(
            query.padding.left,
            0,
            query.padding.right,
            query.viewInsets.bottom + query.padding.bottom,
          );
    final textPadding = InheritedChatTheme.of(context)
        .theme
        .inputPadding
        .copyWith(left: 0, right: 0)
        .add(
          EdgeInsets.fromLTRB(
            widget.onAttachmentPressed != null ? 0 : 24,
            0,
            _sendButtonVisible ? 0 : 24,
            0,
          ),
        );

    return Focus(
      autofocus: true,
      child: Padding(
        padding: InheritedChatTheme.of(context).theme.inputMargin,
        child: Material(
          borderRadius: InheritedChatTheme.of(context).theme.inputBorderRadius,
          color: InheritedChatTheme.of(context).theme.inputBackgroundColor,
          child: Container(
            decoration:
                InheritedChatTheme.of(context).theme.inputContainerDecoration,
            padding: safeAreaInsets,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  textDirection: TextDirection.ltr,
                  children: [
                    if (widget.onAttachmentPressed != null)
                      AttachmentButton(
                        isLoading: widget.isAttachmentUploading ?? false,
                        onPressed: widget.onAttachmentPressed,
                        padding: buttonPadding,
                      ),

                    // Expanded(
                    //   child: Padding(
                    //     padding: textPadding,
                    //     child: TextField(
                    //       controller: _textController,
                    //       cursorColor: InheritedChatTheme.of(context)
                    //           .theme
                    //           .inputTextCursorColor,
                    //       decoration: InheritedChatTheme.of(context)
                    //           .theme
                    //           .inputTextDecoration
                    //           .copyWith(
                    //             hintStyle: InheritedChatTheme.of(context)
                    //                 .theme
                    //                 .inputTextStyle
                    //                 .copyWith(
                    //                   color: InheritedChatTheme.of(context)
                    //                       .theme
                    //                       .inputTextColor
                    //                       .withOpacity(0.5),
                    //                 ),
                    //             hintText:
                    //                 InheritedL10n.of(context).l10n.inputPlaceholder,
                    //           ),
                    //       focusNode: _inputFocusNode,
                    //       keyboardType: TextInputType.multiline,
                    //       maxLines: 5,
                    //       minLines: 1,
                    //       onChanged: widget.onTextChanged,
                    //       onTap: widget.onTextFieldTap,
                    //       style: InheritedChatTheme.of(context)
                    //           .theme
                    //           .inputTextStyle
                    //           .copyWith(
                    //             color: InheritedChatTheme.of(context)
                    //                 .theme
                    //                 .inputTextColor,
                    //           ),
                    //       textCapitalization: TextCapitalization.sentences,
                    //     ),
                    //   ),
                    // ),

                    Expanded(
                      child: MathFormField(
                        onChanged: widget.onTextChanged,
                        controller: _mathController,
                        decoration: InputDecoration(
                          hintStyle: InheritedChatTheme.of(context)
                              .theme
                              .inputTextStyle
                              .copyWith(
                                  color: InheritedChatTheme.of(context)
                                      .theme
                                      .inputTextColor
                                      .withOpacity(0.5),
                                  fontSize: 16),
                          hintText:
                              InheritedL10n.of(context).l10n.inputPlaceholder,
                          border: InputBorder.none,
                        ),
                        focusNode: _inputFocusNode,
                        onFieldSubmitted: (e) {
                          print(e);
                          setState(() {
                            _height = 0;
                          });
                        },
                      ),
                    ),
                    Visibility(
                      visible: _sendButtonVisible,
                      child: SendButton(
                        onPressed: _handleSendPressed,
                        padding: buttonPadding,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    _inputFocusNode.requestFocus();
                    setState(() {
                      _height = 320;
                    });
                  },
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      color: Colors.red.withOpacity(0).withOpacity(0),
                      height: 60,
                      width: 300,
                    ),
                  ),
                ),
                Container(
                  height: _height,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
