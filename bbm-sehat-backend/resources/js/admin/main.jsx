import { createRoot } from 'react-dom/client';
import Login from './pages/Login';
import PengaturanPengguna from './pages/PengaturanPengguna';
import MonitoringRingkasan from './pages/MonitoringRingkasan';
import MonitoringPerDivisi from './pages/MonitoringPerDivisi';
import MonitoringTidakAktif from './pages/MonitoringTidakAktif';
import MonitoringProgresKaryawan from './pages/MonitoringProgresKaryawan';

const root = document.getElementById('admin-root');

if (root) {
    const page = root.dataset.page;
    const app = createRoot(root);

    if (page === 'login') {
        app.render(<Login />);
    } else if (page === 'pengaturan-pengguna') {
        app.render(<PengaturanPengguna employee={JSON.parse(root.dataset.employee)} />);
    } else if (page === 'monitoring-ringkasan') {
        app.render(<MonitoringRingkasan employee={JSON.parse(root.dataset.employee)} />);
    } else if (page === 'monitoring-per-divisi') {
        app.render(<MonitoringPerDivisi employee={JSON.parse(root.dataset.employee)} />);
    } else if (page === 'monitoring-tidak-aktif') {
        app.render(<MonitoringTidakAktif employee={JSON.parse(root.dataset.employee)} />);
    } else if (page === 'monitoring-progres-karyawan') {
        app.render(<MonitoringProgresKaryawan employee={JSON.parse(root.dataset.employee)} />);
    }
}
