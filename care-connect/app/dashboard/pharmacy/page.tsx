import { getMedicines, getAllPatientsList } from '@/lib/actions';
import PharmacyClient from './PharmacyClient';
import { cookies } from 'next/headers';

export default async function PharmacyPage() {
    const medicines = await getMedicines();
    const patients = (await getAllPatientsList()) as any[];

    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;
    if (session) {
        try {
            role = JSON.parse(session.value).role;
        } catch (e) { }
    }

    return <PharmacyClient medicines={medicines} patients={patients} role={role} />;
}
