import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import NewDoctorForm from './new-doctor-form';

export default async function NewDoctorPage() {
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;

    if (session) {
        try {
            const data = JSON.parse(session.value);
            role = data.role;
        } catch (e) {
            // Invalid session
        }
    }

    if (role !== 'Admin') {
        redirect('/dashboard');
    }

    return <NewDoctorForm />;
}
