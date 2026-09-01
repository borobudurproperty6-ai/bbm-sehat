<?php

namespace Tests\Feature\Console;

use App\Enums\AccountStatus;
use App\Models\Division;
use App\Models\Employee;
use Database\Seeders\DivisionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Tests\TestCase;

/**
 * No test previously covered `employees:import` at all. Added now because
 * its temporary-password generator just moved from
 * Str::password(10, symbols: false, spaces: false) to the same
 * TemporaryPasswordGenerator the dashboard's Tambah Pengguna/Reset
 * Password already use — this is the only thing that changed, so this
 * suite both proves the new format and pins down that everything else
 * (role assignment, must_change_password, account_status,
 * is_management) is untouched.
 */
class ImportEmployeesCommandTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD_FORMAT = '/^[A-Z][a-z]+[2-9]{4}$/';

    private string $fixturePath;

    private string $importDir;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DivisionSeeder::class);
        $this->seed(RoleSeeder::class);

        $this->importDir = storage_path('app/import');
        File::ensureDirectoryExists($this->importDir);
        $this->fixturePath = $this->importDir.'/test_fixture_'.uniqid().'.xlsx';
    }

    protected function tearDown(): void
    {
        File::delete($this->fixturePath);
        parent::tearDown();
    }

    /**
     * @param  array<int, array<int, string>>  $rows  Header row first, matching ImportEmployees' expected columns.
     */
    private function writeFixture(array $rows): void
    {
        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();

        foreach ($rows as $i => $row) {
            $sheet->fromArray($row, null, 'A'.($i + 1));
        }

        (new Xlsx($spreadsheet))->save($this->fixturePath);
    }

    /** Finds the CSV this run of the command just wrote (see writePasswordCsv). */
    private function findGeneratedCsv(): string
    {
        $files = collect(File::files($this->importDir))
            ->filter(fn ($f) => str_starts_with($f->getFilename(), 'hasil_password_sementara_'))
            ->sortByDesc(fn ($f) => $f->getMTime());

        $path = $files->first()?->getPathname();
        $this->assertNotNull($path, 'Expected employees:import to write a hasil_password_sementara_*.csv file.');

        return $path;
    }

    public function test_import_generates_password_in_the_new_word_digit_format_and_leaves_other_behavior_unchanged(): void
    {
        // Deliberately NOT the first seeded division — DivisionSeeder
        // inserts 'DIREKTUR' first, which would make is_management true
        // regardless of role and defeat the assertFalse below.
        $division = Division::where('code', 'SDM')->firstOrFail();

        $this->writeFixture([
            ['Nama Lengkap', 'Email', 'No Telepon', 'Kode Divisi', 'Kode Karyawan/NIP', 'Peran', 'Jabatan'],
            ['Budi Import Test', 'budi.importtest@test.local', '081200000000', $division->code, '', 'EMPLOYEE', 'Staff'],
        ]);

        $this->artisan('employees:import', ['path' => $this->fixturePath])
            ->assertExitCode(0);

        $employee = Employee::where('email', 'budi.importtest@test.local')->firstOrFail();

        // ── Behavior that must NOT have changed ─────────────────────────
        $this->assertSame('EMPLOYEE', $employee->role->code);
        $this->assertSame($division->id, $employee->division_id);
        $this->assertTrue($employee->must_change_password);
        $this->assertSame(AccountStatus::Active, $employee->account_status);
        $this->assertFalse($employee->is_management);

        // ── The one thing that DID change: password format ─────────────
        $csvPath = $this->findGeneratedCsv();
        $rows = array_map('str_getcsv', file($csvPath));
        $header = array_shift($rows);
        $passwordColumn = array_search('temporary_password', $header, true);

        $row = collect($rows)->first(fn ($r) => $r[array_search('email', $header, true)] === 'budi.importtest@test.local');
        $this->assertNotNull($row, 'Imported row not found in the generated CSV.');

        $plaintextPassword = $row[$passwordColumn];
        $this->assertMatchesRegularExpression(self::PASSWORD_FORMAT, $plaintextPassword);
        $this->assertTrue(Hash::check($plaintextPassword, $employee->password));

        File::delete($csvPath);
    }

    public function test_management_division_still_sets_is_management_true(): void
    {
        // Untouched business rule (EmployeeController isn't involved here,
        // this command has its own is_management logic) — confirming the
        // password-generator swap didn't disturb it. DIREKTUR is already
        // seeded by DivisionSeeder, used directly by code below.
        $this->writeFixture([
            ['Nama Lengkap', 'Email', 'No Telepon', 'Kode Divisi', 'Kode Karyawan/NIP', 'Peran', 'Jabatan'],
            ['Direktur Test', 'direktur.importtest@test.local', '', 'DIREKTUR', '', 'MANAGEMENT', 'Direktur Utama'],
        ]);

        $this->artisan('employees:import', ['path' => $this->fixturePath])->assertExitCode(0);

        $employee = Employee::where('email', 'direktur.importtest@test.local')->firstOrFail();
        $this->assertTrue($employee->is_management);

        File::delete($this->findGeneratedCsv());
    }
}
