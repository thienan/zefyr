// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';

import 'caret.dart';
import 'render_context.dart';

class EditableBox extends SingleChildRenderObjectWidget {
  EditableBox({
    @required Widget child,
    @required this.node,
    @required this.layerLink,
    @required this.renderContext,
    @required this.showCursor,
    @required this.selection,
    @required this.selectionColor,
  }) : super(child: child);

  final ContainerNode node;
  final LayerLink layerLink;
  final ZefyrRenderContext renderContext;
  final ValueNotifier<bool> showCursor;
  final TextSelection selection;
  final Color selectionColor;

  @override
  RenderEditableProxyBox createRenderObject(BuildContext context) {
    return new RenderEditableProxyBox(
      node: node,
      layerLink: layerLink,
      renderContext: renderContext,
      showCursor: showCursor,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderEditableProxyBox renderObject) {
    renderObject
      ..node = node
      ..layerLink = layerLink
      ..renderContext = renderContext
      ..showCursor = showCursor
      ..selection = selection
      ..selectionColor = selectionColor;
  }
}

class RenderEditableProxyBox extends RenderBox
    with
        RenderObjectWithChildMixin<RenderEditableBox>,
        RenderProxyBoxMixin<RenderEditableBox>
    implements RenderEditableBox {
  RenderEditableProxyBox({
    RenderEditableBox child,
    @required ContainerNode node,
    @required LayerLink layerLink,
    @required ZefyrRenderContext renderContext,
    @required ValueNotifier<bool> showCursor,
    @required TextSelection selection,
    @required Color selectionColor,
  })  : _node = node,
        _layerLink = layerLink,
        _renderContext = renderContext,
        _showCursor = showCursor,
        _selection = selection,
        _selectionColor = selectionColor,
        super() {
    this.child = child;
  }

  ContainerNode get node => _node;
  ContainerNode _node;
  void set node(ContainerNode value) {
    _node = value;
  }

  LayerLink get layerLink => _layerLink;
  LayerLink _layerLink;
  void set layerLink(LayerLink value) {
    if (_layerLink == value) return;
    _layerLink = value;
  }

  ZefyrRenderContext _renderContext;
  void set renderContext(ZefyrRenderContext value) {
    if (_renderContext == value) return;
    if (attached) _renderContext.removeBox(this);
    _renderContext = value;
    if (attached) _renderContext.addBox(this);
  }

  ValueNotifier<bool> _showCursor;
  set showCursor(ValueNotifier<bool> value) {
    assert(value != null);
    if (_showCursor == value) return;
    if (attached) _showCursor.removeListener(markNeedsPaint);
    _showCursor = value;
    if (attached) _showCursor.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// Current document selection.
  TextSelection get selection => _selection;
  TextSelection _selection;
  set selection(TextSelection value) {
    if (_selection == value) return;
    // TODO: check if selection affects this block (also check previous value)
    _selection = value;
    markNeedsPaint();
  }

  /// Color of selection.
  Color get selectionColor => _selectionColor;
  Color _selectionColor;
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  /// Returns `true` if current selection is collapsed, located within
  /// this paragraph and is visible according to tick timer.
  bool get isCaretVisible {
    if (!_selection.isCollapsed) return false;
    if (!_showCursor.value) return false;

    final int start = node.documentOffset;
    final int end = start + node.length;
    final int caretOffset = _selection.extentOffset;
    return caretOffset >= start && caretOffset < end;
  }

  /// Returns `true` if selection is not collapsed and intersects with this
  /// paragraph.
  bool get isSelectionVisible {
    if (_selection.isCollapsed) return false;
    return intersectsWithSelection(_selection);
  }

  //
  // Overridden members of RenderBox
  //

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _showCursor.addListener(markNeedsPaint);
    _renderContext.addBox(this);
  }

  @override
  void detach() {
    _showCursor.removeListener(markNeedsPaint);
    _renderContext.removeBox(this);
    super.detach();
  }

  @override
  @mustCallSuper
  void performLayout() {
    super.performLayout();
    _caretPainter.layout(preferredLineHeight);
    // Indicate to render context that this object can be used by other
    // layers (selection overlay, for instance).
    _renderContext.markDirty(this, false);
  }

  @override
  void markNeedsLayout() {
    // Temporarily remove this object from the render context.
    _renderContext.markDirty(this, true);
    super.markNeedsLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (selectionOrder == SelectionOrder.background && isSelectionVisible) {
      paintSelection(context, offset, selection, selectionColor);
    }
    super.paint(context, offset);
    if (selectionOrder == SelectionOrder.foreground && isSelectionVisible) {
      paintSelection(context, offset, selection, selectionColor);
    }
    if (isCaretVisible) {
      _paintCaret(context, offset);
    }
  }

  final CaretPainter _caretPainter = new CaretPainter();

  void _paintCaret(PaintingContext context, Offset offset) {
    Offset caretOffset =
        getOffsetForCaret(_selection.extent, _caretPainter.prototype);
    _caretPainter.paint(context.canvas, caretOffset + offset);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTest(HitTestResult result, {Offset position}) {
    if (size.contains(position)) {
      result.add(new BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  //
  // Proxy methods
  //

  @override
  double get preferredLineHeight => child.preferredLineHeight;

  @override
  SelectionOrder get selectionOrder => child.selectionOrder;

  @override
  void paintSelection(PaintingContext context, Offset offset,
          TextSelection selection, Color selectionColor) =>
      child.paintSelection(context, offset, selection, selectionColor);

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) =>
      child.getOffsetForCaret(position, caretPrototype);

  @override
  TextSelection getLocalSelection(TextSelection documentSelection) =>
      child.getLocalSelection(documentSelection);

  bool intersectsWithSelection(TextSelection selection) =>
      child.intersectsWithSelection(selection);

  @override
  List<ui.TextBox> getEndpointsForSelection(TextSelection selection) =>
      child.getEndpointsForSelection(selection);

  @override
  ui.TextPosition getPositionForOffset(ui.Offset offset) =>
      child.getPositionForOffset(offset);

  @override
  TextRange getWordBoundary(ui.TextPosition position) =>
      child.getWordBoundary(position);
}

enum SelectionOrder {
  /// Background selection is painted before primary content of editable box.
  background,

  /// Foreground selection is painted after primary content of editable box.
  foreground,
}

abstract class RenderEditableBox extends RenderBox {
  Node get node;
  double get preferredLineHeight;

  TextPosition getPositionForOffset(Offset offset);
  List<ui.TextBox> getEndpointsForSelection(TextSelection selection);

  /// Returns the text range of the word at the given offset. Characters not
  /// part of a word, such as spaces, symbols, and punctuation, have word breaks
  /// on both sides. In such cases, this method will return a text range that
  /// contains the given text position.
  ///
  /// Word boundaries are defined more precisely in Unicode Standard Annex #29
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>.
  ///
  /// Valid only after [layout].
  TextRange getWordBoundary(TextPosition position);

  /// Paint order of selection in this editable box.
  SelectionOrder get selectionOrder;

  void paintSelection(PaintingContext context, Offset offset,
      TextSelection selection, Color selectionColor);

  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype);

  /// Returns part of [documentSelection] local to this box. May return
  /// `null`.
  ///
  /// [documentSelection] must not be collapsed.
  TextSelection getLocalSelection(TextSelection documentSelection) {
    if (!intersectsWithSelection(documentSelection)) return null;

    int nodeBase = node.documentOffset;
    int nodeExtent = nodeBase + node.length;
    int base = math.max(0, documentSelection.baseOffset - nodeBase);
    int extent =
        math.min(documentSelection.extentOffset, nodeExtent) - nodeBase;
    return documentSelection.copyWith(baseOffset: base, extentOffset: extent);
  }

  /// Returns `true` if this box intersects with document [selection].
  bool intersectsWithSelection(TextSelection selection) {
    final int base = node.documentOffset;
    final int extent = base + node.length;
    return base <= selection.extentOffset && selection.baseOffset <= extent;
  }
}
