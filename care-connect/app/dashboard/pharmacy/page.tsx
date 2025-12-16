import { getMedicines, getAllPatientsList } from '@/lib/actions';
import PharmacyClient from './PharmacyClient';

export default async function PharmacyPage() {
    const medicines = await getMedicines();
    const patients = (await getAllPatientsList()) as any[];

    return <PharmacyClient medicines={medicines} patients={patients} />;
}
