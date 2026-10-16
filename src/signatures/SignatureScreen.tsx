import { useRef, useState } from 'react';
import { Alert, Image, PanResponder, ScrollView, Text, TextInput, View } from 'react-native';
import Svg, { Polyline } from 'react-native-svg';
import { useFocusEffect } from 'expo-router';
import { useCallback } from 'react';
import type { Point, Signature, Stroke } from '../scanner/types';
import { scanner } from '../scanner/native';
import { Action, Row, showError, styles, useColors } from '../components/ui';

export default function SignatureScreen() {
  const c = useColors();
  const [strokes, setStrokes] = useState<Stroke[]>([]), [color, setColor] = useState('#111111'), [signatures, setSignatures] = useState<Signature[]>([]), [busy, setBusy] = useState(false);
  const [name, setName] = useState('Signature');
  const [drawing, setDrawing] = useState(false);
  const size = useRef({ width: 1, height: 1 });
  const points = useRef<Point[]>([]);
  const reload = useCallback(async () => setSignatures(await scanner.listSignatures()), []);
  useFocusEffect(useCallback(() => { void reload().catch(showError); }, [reload]));
  function normalized(x: number, y: number): Point { return { x: Math.max(0, Math.min(1,x/size.current.width)), y: Math.max(0,Math.min(1,y/size.current.height)) }; }
  const pan = PanResponder.create({
    onStartShouldSetPanResponder: () => !busy,
    onMoveShouldSetPanResponder: () => !busy,
    onPanResponderGrant: event => { setDrawing(true); points.current = [normalized(event.nativeEvent.locationX,event.nativeEvent.locationY)]; setStrokes(previous => [...previous,{ points: [...points.current], color, width: 0.003 }]); },
    onPanResponderMove: event => { points.current.push(normalized(event.nativeEvent.locationX,event.nativeEvent.locationY)); setStrokes(previous => [...previous.slice(0,-1),{ points: [...points.current], color, width: 0.003 }]); },
    onPanResponderRelease: () => setDrawing(false),
    onPanResponderTerminate: () => setDrawing(false),
  });
  return <ScrollView contentContainerStyle={styles.content} style={{ backgroundColor: c.background }} scrollEnabled={!drawing}>
    <Text style={{ color: c.text, fontSize: 20 }}>Draw your signature</Text>
    <Text style={{ color: c.secondary }}>These are visual signatures, not cryptographic digital signatures.</Text>
    <View accessibilityLabel="Signature drawing area" {...pan.panHandlers} onLayout={event => { size.current = event.nativeEvent.layout; }} style={{ width: '100%', aspectRatio: 2.5, backgroundColor: '#FFFFFF', borderColor: '#727272', borderWidth: 1 }}>
      <Svg pointerEvents="none" width="100%" height="100%" viewBox="0 0 1 1" preserveAspectRatio="none">{strokes.map((stroke,i) => <Polyline key={i} points={stroke.points.map(p => `${p.x},${p.y}`).join(' ')} fill="none" stroke={stroke.color} strokeWidth={0.005} strokeLinecap="round" strokeLinejoin="round" />)}</Svg>
    </View>
    <Row>{[['Black','#111111'],['Blue','#1546A0'],['Red','#A01919']].map(([label,value]) => <Action key={value} title={label!} selected={color === value} onPress={() => setColor(value!)} />)}<Action title="Clear drawing" onPress={() => setStrokes([])} /></Row>
    <TextInput accessibilityLabel="Signature name" value={name} onChangeText={setName} style={[styles.input,{ color:c.text,borderColor:c.border }]} />
    <Action title="Save signature" disabled={busy || !strokes.some(s => s.points.length > 1) || !name.trim()} onPress={() => { setBusy(true); void scanner.saveSignature(strokes).then(async value => { await scanner.renameSignature(value.id,name); setStrokes([]); await reload(); }).catch(showError).finally(() => setBusy(false)); }} />
    <Text style={{ color:c.text,fontSize:20 }}>Saved signatures</Text>
    {signatures.map(signature => <View key={signature.id} style={{ gap:8 }}><Image source={{ uri:signature.imageUri }} style={{ width:200,height:80,backgroundColor:'#FFFFFF' }} resizeMode="contain" /><Text style={{ color:c.text }}>{signature.name}</Text><Row>
      <Action title={`Rename ${signature.name}`} onPress={() => Alert.prompt('Rename signature',undefined,value => { if (value) void scanner.renameSignature(signature.id,value).then(reload).catch(showError); },'plain-text',signature.name)} />
      <Action title={`Delete ${signature.name}`} danger onPress={() => Alert.alert('Delete reusable signature?','Copies already placed in documents are kept.',[{ text:'Cancel',style:'cancel' },{ text:'Delete',style:'destructive',onPress:() => { void scanner.deleteSignature(signature.id).then(reload).catch(showError); } }])} />
    </Row></View>)}
  </ScrollView>;
}
