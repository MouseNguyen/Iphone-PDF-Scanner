import { useRef, useState } from 'react';
import { Image, PanResponder, Text, View } from 'react-native';
import type { Point, Quad } from '../scanner/types';
import { validQuad } from './geometry';
import { Action, Row, useColors } from '../components/ui';

const full: Quad = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }];
export default function CropEditor({ uri, initial, onApply, onCancel }: { uri: string; initial?: Quad; onApply: (points: Quad) => void; onCancel: () => void }) {
  const c = useColors();
  const [points, setPoints] = useState<Quad>(initial ?? full), [selected, setSelected] = useState(0);
  const [size, setSize] = useState({ width: 1, height: 1 });
  const [aspect, setAspect] = useState(0.72);
  const start = useRef<Point>({ x: 0, y: 0 });
  const activeCorner = useRef(0);
  function move(index: number, point: Point) {
    setPoints(previous => previous.map((p, i) => i === index ? { x: Math.max(0, Math.min(1, point.x)), y: Math.max(0, Math.min(1, point.y)) } : p) as Quad);
  }
  const pan = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onPanResponderGrant: event => {
      const x = event.nativeEvent.locationX / size.width, y = event.nativeEvent.locationY / size.height;
      const index = points.reduce((best, p, i) => Math.hypot(p.x-x,p.y-y) < Math.hypot(points[best]!.x-x,points[best]!.y-y) ? i : best, 0);
      setSelected(index); activeCorner.current = index; start.current = { ...points[index]! };
    },
    onPanResponderMove: (_event, gesture) => move(activeCorner.current, { x: start.current.x + gesture.dx / size.width, y: start.current.y + gesture.dy / size.height }),
  });
  return <View style={{ gap: 12 }}>
    <Text style={{ color: c.text }}>Drag the four corners. This adjusts the retained image; a bad initial camera crop may need a retake.</Text>
    <View {...pan.panHandlers} onLayout={event => setSize(event.nativeEvent.layout)} style={{ width: '100%', aspectRatio: aspect, backgroundColor: c.surface }}>
      <Image source={{ uri }} onLoad={({ nativeEvent }) => { if (nativeEvent.source.width > 0 && nativeEvent.source.height > 0) setAspect(nativeEvent.source.width/nativeEvent.source.height); }} style={{ width: '100%', height: '100%' }} resizeMode="stretch" />
      {points.map((p, i) => <View pointerEvents="none" key={i} style={{ position: 'absolute', left: `${p.x*100}%`, top: `${p.y*100}%`, width: 20, height: 20, marginLeft: -10, marginTop: -10, borderRadius: 10, borderWidth: 3, borderColor: '#FFFFFF', backgroundColor: '#1546A0' }} />)}
    </View>
    <Row>{['Top left', 'Top right', 'Bottom right', 'Bottom left'].map((name, i) => <Action key={name} title={name} selected={selected === i} onPress={() => setSelected(i)} />)}</Row>
    <Row>{([['Left', -0.01, 0], ['Right', 0.01, 0], ['Up', 0, -0.01], ['Down', 0, 0.01]] as const).map(([name, x, y]) => <Action key={name} title={name} onPress={() => move(selected, { x: points[selected]!.x+x, y: points[selected]!.y+y })} />)}</Row>
    <Row><Action title="Apply crop" disabled={!validQuad(points)} onPress={() => onApply(points)} /><Action title="Cancel crop" onPress={onCancel} /></Row>
  </View>;
}
