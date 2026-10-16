import type { Mode } from '../scanner/types';
import { Action, Row } from '../components/ui';
export default function ModeChooser({ mode, onChange }: { mode: Mode; onChange: (mode: Mode) => void }) {
  return <Row>{(['document', 'id', 'photo'] as const).map(value => <Action key={value} title={value === 'id' ? 'ID card' : value === 'photo' ? 'Photo' : 'Document'} selected={mode === value} onPress={() => onChange(value)} />)}</Row>;
}
