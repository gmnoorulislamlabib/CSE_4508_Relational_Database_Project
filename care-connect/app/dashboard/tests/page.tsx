import { getAvailableTests, getAllPatientsList, getAllDoctorsList } from '@/lib/actions';
import TestsClient from './TestsClient';

export default async function TestsPage() {
    let tests = [];
    let patients = [];
    let doctors = [];
    let error = null;

    try {
        tests = await getAvailableTests() as any[];
        patients = await getAllPatientsList() as any[];
        doctors = await getAllDoctorsList() as any[];
    } catch (e: any) {
        error = e.message;
    }

    if (error) {
        return (
            <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
                Failed to load data: {error}
            </div>
        );
    }

    return <TestsClient tests={tests} patients={patients} doctors={doctors} />;
}
