import 'dart:convert';

import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showMcpSchemaFormDialog(
  BuildContext context, {
  required String toolName,
  required Map<String, dynamic> schema,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _McpSchemaFormDialog(
      toolName: toolName,
      schema: schema,
    ),
  );
}

class _McpSchemaFormDialog extends StatefulWidget {
  const _McpSchemaFormDialog({
    required this.toolName,
    required this.schema,
  });

  final String toolName;
  final Map<String, dynamic> schema;

  @override
  State<_McpSchemaFormDialog> createState() =>
      _McpSchemaFormDialogState();
}

class _McpSchemaFormDialogState extends State<_McpSchemaFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _value;

  @override
  void initState() {
    super.initState();
    _value = Map<String, dynamic>.from(
      _schemaDefault(widget.schema) as Map? ?? const <String, dynamic>{},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('/${widget.toolName}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: _SchemaField(
              schema: widget.schema,
              value: _value,
              required: true,
              onChanged: (value) {
                setState(() {
                  _value = Map<String, dynamic>.from(
                    value as Map? ?? const <String, dynamic>{},
                  );
                });
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _value);
          },
          child: const Text('调用'),
        ),
      ],
    );
  }
}

class _SchemaField extends StatelessWidget {
  const _SchemaField({
    super.key,
    required this.schema,
    required this.value,
    required this.required,
    required this.onChanged,
    this.label,
  });

  final Map<String, dynamic> schema;
  final dynamic value;
  final bool required;
  final ValueChanged<dynamic> onChanged;
  final String? label;

  String? get _description => schema['description']?.toString();

  @override
  Widget build(BuildContext context) {
    final type = schema['type']?.toString();
    if (type == 'object' || schema['properties'] is Map) {
      final object = value is Map
          ? Map<String, dynamic>.from(value as Map)
          : <String, dynamic>{};
      final properties = schema['properties'] is Map
          ? Map<String, dynamic>.from(schema['properties'] as Map)
          : const <String, dynamic>{};
      final requiredFields = schema['required'] is List
          ? (schema['required'] as List).map((item) => item.toString()).toSet()
          : const <String>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(label!, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
          ],
          for (final entry in properties.entries) ...[
            _SchemaField(
              key: ValueKey(entry.key),
              schema: entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{},
              value: object[entry.key],
              required: requiredFields.contains(entry.key),
              label: entry.value is Map
                  ? (entry.value as Map)['title']?.toString() ?? entry.key
                  : entry.key,
              onChanged: (next) => onChanged({...object, entry.key: next}),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    if (type == 'boolean') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('${label ?? ''}${required ? ' *' : ''}'),
        subtitle: _description == null ? null : Text(_description!),
        value: value == true,
        onChanged: onChanged,
      );
    }

    final enumValues = schema['enum'] is List
        ? List<dynamic>.from(schema['enum'] as List)
        : const <dynamic>[];
    if (enumValues.isNotEmpty) {
      final selected = enumValues.contains(value) ? value : null;
      return DropdownButtonFormField<dynamic>(
        initialValue: selected,
        decoration: _decoration(),
        items: enumValues
            .map((item) => DropdownMenuItem(value: item, child: Text('$item')))
            .toList(growable: false),
        onChanged: onChanged,
        validator: (candidate) => required && candidate == null ? '此项必填' : null,
      );
    }

    if (type == 'array') {
      return _JsonArrayField(
        label: label,
        description: _description,
        required: required,
        value: value is List ? value as List : const [],
        onChanged: onChanged,
      );
    }

    final numeric = type == 'number' || type == 'integer';
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: _decoration(),
      validator: (candidate) {
        final text = candidate?.trim() ?? '';
        if (required && text.isEmpty) return '此项必填';
        if (text.isEmpty || !numeric) return null;
        if (type == 'integer' && int.tryParse(text) == null) return '请输入整数';
        if (type == 'number' && double.tryParse(text) == null) return '请输入数字';
        return null;
      },
      onChanged: (text) {
        if (!numeric) return onChanged(text);
        if (type == 'integer') return onChanged(int.tryParse(text));
        onChanged(double.tryParse(text));
      },
    );
  }

  InputDecoration _decoration() => InputDecoration(
    labelText: '${label ?? ''}${required ? ' *' : ''}',
    helperText: _description,
    border: const OutlineInputBorder(),
  );
}

class _JsonArrayField extends StatefulWidget {
  const _JsonArrayField({
    required this.label,
    required this.description,
    required this.required,
    required this.value,
    required this.onChanged,
  });

  final String? label;
  final String? description;
  final bool required;
  final List<dynamic> value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_JsonArrayField> createState() => _JsonArrayFieldState();
}

class _JsonArrayFieldState extends State<_JsonArrayField> {
  late final TextEditingController _controller = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(widget.value),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: '${widget.label ?? ''}${widget.required ? ' *' : ''}',
        helperText: widget.description ?? '使用 JSON 数组格式',
        border: const OutlineInputBorder(),
      ),
      validator: (source) {
        try {
          final decoded = jsonDecode(source ?? '');
          if (decoded is! List) return '请输入 JSON 数组';
          if (widget.required && decoded.isEmpty) return '此项必填';
          return null;
        } catch (_) {
          return 'JSON 数组格式无效';
        }
      },
      onChanged: (source) {
        try {
          final decoded = jsonDecode(source);
          if (decoded is List) widget.onChanged(decoded);
        } catch (_) {
          // The validator reports incomplete JSON when the user submits.
        }
      },
    );
  }
}

dynamic _schemaDefault(Map<String, dynamic> schema) {
  if (schema.containsKey('default')) return schema['default'];
  final type = schema['type']?.toString();
  if (type == 'object' || schema['properties'] is Map) {
    final properties = schema['properties'] is Map
        ? Map<String, dynamic>.from(schema['properties'] as Map)
        : const <String, dynamic>{};
    return {
      for (final entry in properties.entries)
        if (entry.value is Map &&
            _schemaDefault(Map<String, dynamic>.from(entry.value as Map)) != null)
          entry.key: _schemaDefault(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    };
  }
  if (type == 'array') return <dynamic>[];
  if (type == 'boolean') return false;
  return null;
}
