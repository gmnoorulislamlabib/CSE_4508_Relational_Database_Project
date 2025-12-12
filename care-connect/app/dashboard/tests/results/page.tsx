
import { getPendingTests } from '@/lib/actions';
import { ResultsClient } from './ResultsClient';

export default async function TestResultsPage() {
    const orders = await getPendingTests();
    return <ResultsClient orders={orders as any[]} />;
}
