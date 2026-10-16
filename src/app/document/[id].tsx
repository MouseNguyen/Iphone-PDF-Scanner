import { useLocalSearchParams } from 'expo-router';
import ReviewScreen from '../../document/ReviewScreen';
export default function DocumentRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <ReviewScreen key={id} id={id} />;
}
