
'use client';

import { useState } from 'react';
import { Building2, Bed, Activity } from 'lucide-react';

export default function ReceptionRoomList({ availableRooms }: { availableRooms: any[] }) {
    // Grouping Rooms
    const groupedRooms = availableRooms.reduce((acc: any, room: any) => {
        const type = room.type;
        if (!acc[type]) acc[type] = [];
        acc[type].push(room);
        return acc;
    }, {});

    const roomTypeLabels: any = {
        'Ward_NonAC': 'General Ward (Non-AC)',
        'Ward_AC': 'General Ward (AC)',
        'ICU': 'Intensive Care Unit (ICU)',
        'Operation_Theater': 'Operation Theater',
        'Consultation': 'Consultation Rooms',
        'Lab': 'Laboratory Rooms'
    };

    return (
        <div className="space-y-8">
            {Object.keys(groupedRooms).length === 0 && (
                <div className="p-8 text-center text-slate-500 bg-white rounded-xl border border-slate-200">
                    <Building2 className="w-12 h-12 text-slate-300 mx-auto mb-3" />
                    <p>No rooms are currently available.</p>
                </div>
            )}

            {Object.keys(groupedRooms).map((type) => (
                <div key={type} className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in">
                    <div className="px-6 py-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
                        <h3 className="font-semibold text-slate-800 flex items-center gap-2">
                            {type === 'ICU' ? <Activity className="text-red-500" /> : <Bed className="text-blue-500" />}
                            {roomTypeLabels[type] || type}
                        </h3>
                        <span className="text-xs font-medium px-2.5 py-1 bg-green-100 text-green-700 rounded-full">
                            {groupedRooms[type].length} Available
                        </span>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 p-6">
                        {groupedRooms[type].map((room: any) => (
                            <div
                                key={room.room_number}
                                className="flex flex-col items-center justify-center p-4 rounded-xl border border-slate-200 bg-slate-50 text-left w-full relative cursor-default"
                            >
                                <div className={`w-10 h-10 rounded-full flex items-center justify-center mb-3 
                                    ${room.type === 'ICU' ? 'bg-red-100 text-red-600' :
                                        room.type === 'Operation_Theater' ? 'bg-orange-100 text-orange-600' : 'bg-blue-100 text-blue-600'}`}>
                                    {room.type === 'ICU' || room.type === 'Operation_Theater' ? <Activity size={20} /> : <Bed size={20} />}
                                </div>
                                <h4 className="font-bold text-slate-900">{room.room_number}</h4>
                                <span className="text-xs text-slate-500 mt-1">
                                    {Number(room.charge_per_day) > 0 ? `৳${room.charge_per_day}/day` : 'Standard'}
                                </span>
                            </div>
                        ))}
                    </div>
                </div>
            ))}
        </div>
    );
}

// Removed AdmissionModal as bookings are disabled here.
