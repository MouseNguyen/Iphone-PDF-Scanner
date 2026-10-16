import { useState } from 'react';
import { Text, View } from 'react-native';
import type { SignaturePlacement } from '../scanner/types';
import { Action, Row, useColors } from '../components/ui';

export default function PlacementEditor({ initial, onApply, onCancel }: { initial: SignaturePlacement; onApply: (value: SignaturePlacement | null) => void; onCancel: () => void }) {
  const c = useColors();
  const [value, setValue] = useState(initial);
  function change(dx: number, dy: number, scale = 1) {
    setValue(p => {
      const width = Math.max(0.05, Math.min(0.9, p.width*scale)), height = Math.max(0.02, Math.min(0.9, p.height*scale));
      return { ...p, width, height, x: Math.max(0, Math.min(1-width, p.x+dx)), y: Math.max(0, Math.min(1-height, p.y+dy)) };
    });
  }
  return <View style={{ gap: 10 }}><Text style={{ color: c.text }}>Position: {Math.round(value.x*100)}%, {Math.round(value.y*100)}% · width {Math.round(value.width*100)}% · rotation {Math.round(value.radians*180/Math.PI)}°</Text>
    <Row><Action title="Left" onPress={() => change(-0.025,0)} /><Action title="Right" onPress={() => change(0.025,0)} /><Action title="Up" onPress={() => change(0,-0.025)} /><Action title="Down" onPress={() => change(0,0.025)} /></Row>
    <Row><Action title="Smaller" onPress={() => change(0,0,0.9)} /><Action title="Larger" onPress={() => change(0,0,1.1)} /><Action title="Rotate signature" onPress={() => setValue(p => ({ ...p, radians: p.radians+Math.PI/12 }))} /><Action title="Mirror signature" onPress={() => setValue(p => ({ ...p, mirrored: !p.mirrored }))} /></Row>
    <Row><Action title="Apply placement" onPress={() => onApply(value)} /><Action title="Remove signature" danger onPress={() => onApply(null)} /><Action title="Cancel placement" onPress={onCancel} /></Row>
  </View>;
}
