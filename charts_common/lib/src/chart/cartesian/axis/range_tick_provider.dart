// Copyright 2018 the Charts project authors. Please see the AUTHORS file
// for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.



import '../../../common/graphics_factory.dart' show GraphicsFactory;
import '../../common/chart_context.dart' show ChartContext;
import 'axis.dart' show AxisOrientation;
import 'draw_strategy/tick_draw_strategy.dart' show TickDrawStrategy;
import 'numeric_scale.dart' show NumericScale;
import 'range_tick.dart' show RangeTick;
import 'scale.dart' show MutableScale;
import 'spec/range_tick_spec.dart' show RangeTickSpec;
import 'spec/tick_spec.dart' show TickSpec;
import 'tick.dart' show Tick;
import 'tick_formatter.dart' show TickFormatter;
import 'tick_provider.dart' show TickProvider, TickHint;
import 'time/date_time_scale.dart' show DateTimeScale;

/// A strategy that provides normal ticks and range ticks.
class RangeTickProvider<D> extends TickProvider<D?> {
  final List<TickSpec<D>> tickSpec;
  RangeTickProvider(this.tickSpec);

  @override
  List<Tick<D>?> getTicks({
    required ChartContext? context,
    required GraphicsFactory? graphicsFactory,
    required MutableScale<D?>? scale,
    required TickFormatter<D?>? formatter,
    required Map<D?, String> formatterValueCache,
    required TickDrawStrategy? tickDrawStrategy,
    required AxisOrientation? orientation,
    bool viewportExtensionEnabled = false,
    TickHint<D?>? tickHint,
  }) {
    final ticks = <Tick<D>?>[];

    bool allTicksHaveLabels = true;

    for (TickSpec<D> spec in tickSpec) {
      // When static ticks are being used with a numeric axis, extend the axis
      // with the values specified.
      if (scale is NumericScale || scale is DateTimeScale) {
        scale!.addDomain(spec.value);
        if (spec is RangeTickSpec) {
          final rangeSpec = spec as RangeTickSpec;
          scale.addDomain(rangeSpec.rangeStartValue);
          scale.addDomain(rangeSpec.rangeEndValue);
        }
      }

      // Save off whether all ticks have labels.
      allTicksHaveLabels &= spec.label != null;
    }

    // Use the formatter's label if the tick spec does not provide one.
    late List<String> formattedValues;
    if (allTicksHaveLabels == false) {
      formattedValues = formatter!.format(
          tickSpec.map((spec) => spec.value).toList(), formatterValueCache,
          stepSize: scale!.domainStepSize);
    }

    for (var i = 0; i < tickSpec.length; i++) {
      final spec = tickSpec[i];
      Tick<D>? tick;

      if (spec is RangeTickSpec) {
        // If it is a range tick, we still check if the spec's start and end
        // points are within the viewport because we do not extend the axis for
        // OrdinalScale.
        final rangeSpec = spec as RangeTickSpec;
        if (scale!.compareDomainValueToViewport(rangeSpec.rangeStartValue) ==
                0 &&
            scale.compareDomainValueToViewport(rangeSpec.rangeEndValue) == 0) {
          tick = RangeTick<D>(
            value: rangeSpec.value,
            textElement: graphicsFactory!
                .createTextElement(rangeSpec.label ?? formattedValues[i]),
            locationPx: scale[rangeSpec.rangeStartValue] +
                (scale[rangeSpec.rangeEndValue] -
                        scale[rangeSpec.rangeStartValue]) /
                    2,
            rangeStartValue: rangeSpec.rangeStartValue,
            rangeStartLocationPx: scale[rangeSpec.rangeStartValue] as double?,
            rangeEndValue: rangeSpec.rangeEndValue,
            rangeEndLocationPx: scale[rangeSpec.rangeEndValue] as double?,
          );
        }
      } else {
        // If it is a normal tick, we still check if the spec is within the
        // viewport because we do not extend the axis for OrdinalScale.
        if (scale!.compareDomainValueToViewport(spec.value) == 0) {
          tick = Tick<D>(
            value: spec.value,
            textElement: graphicsFactory!
                .createTextElement(spec.label ?? formattedValues[i]),
            locationPx: scale[spec.value] as double?,
          );
        }
      }

      if (spec.style != null) {
        tick!.textElement!.textStyle = graphicsFactory!.createTextPaint()
          ..fontFamily = spec.style!.fontFamily
          ..fontSize = spec.style!.fontSize
          ..color = spec.style!.color
          ..lineHeight = spec.style!.lineHeight;
      }
      ticks.add(tick);
    }

    // Allow draw strategy to decorate the ticks.
    tickDrawStrategy!.decorateTicks(ticks);

    return ticks;
  }

  @override
  bool operator ==(other) =>
      other is RangeTickProvider && tickSpec == other.tickSpec;

  @override
  int get hashCode => tickSpec.hashCode;
}
