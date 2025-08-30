<?php
// index.php - simple CA web UI
$DATA_DIR = '/data/ca';
$INT_DIR = "$DATA_DIR/intermediate";
$ROOT_DIR = "$DATA_DIR/root";

function fingerprint_from_pem($pem) {
    // compute SHA256 fingerprint - returns lower hex
    $tmp = tempnam(sys_get_temp_dir(), "cert");
    file_put_contents($tmp, $pem);
    $out = trim(shell_exec("openssl x509 -noout -in $tmp -fingerprint -sha256 2>/dev/null"));
    unlink($tmp);
    if (!$out) return null;
    $fp = preg_replace('/^.*=/','',$out);
    $fp = str_replace(':','',$fp);
    return strtolower($fp);
}

function get_admin_fp() {
    $fn = "$DATA_DIR/admin.fingerprint";
    if (file_exists($fn)) return trim(file_get_contents($fn));
    return null;
}

function save_admin_files($keyP, $certP, $pfxPath) {
    global $INT_DIR, $DATA_DIR;
    // store admin cert & fingerprint
    file_put_contents("$INT_DIR/private/admin.key.pem", $keyP);
    file_put_contents("$INT_DIR/certs/admin.crt.pem", $certP);
    // compute fp
    $fp = fingerprint_from_pem($certP);
    file_put_contents("$DATA_DIR/admin.fingerprint", $fp);
    // create pfx for download
    file_put_contents("$INT_DIR/certs/admin.pfx", file_get_contents($pfxPath));
    chmod("$INT_DIR/private/admin.key.pem", 0600);
    chmod("$INT_DIR/certs/admin.crt.pem", 0644);
}

function is_admin_authenticated() {
    if (empty($_SERVER['SSL_CLIENT_CERT'])) return false;
    $cert = openssl_x509_parse($_SERVER['SSL_CLIENT_CERT']);
    if (!$cert) return false;
    // look for SAN entry
    $sans = $cert['extensions']['subjectAltName'] ?? '';
    return (strpos($sans, 'DNS:admin.local') !== false ||
            strpos($sans, 'email:admin@example.com') !== false);
}


$action = $_REQUEST['action'] ?? null;

// Ensure CA exists
if (!file_exists("$ROOT_DIR/ca.crt.pem") || !file_exists("$INT_DIR/certs/inter.crt.pem")) {
    echo "<h2>CA not initialized. Please check container logs.</h2>";
    exit;
}

// Handle admin creation: first-run (when admin fingerprint file not present)
if (!get_admin_fp() && $_SERVER['REQUEST_METHOD'] === 'POST' && $action === 'create_admin') {
    // create admin via gen_cert.sh with type admin
    $cn = escapeshellarg($_POST['cn'] ?? 'admin');
    $out_prefix = 'admin';
    // call script
    $cmd = "DATA_DIR=$DATA_DIR /usr/local/bin/scripts/gen_cert.sh $cn admin $out_prefix";
    exec($cmd, $out, $rc);
    if ($rc !== 0) {
        echo "Failed generating admin cert.<pre>".htmlspecialchars(implode("\n",$out))."</pre>";
        exit;
    }
    // scripts create key and pfx at intermediate path
    $keyP = file_get_contents("$INT_DIR/private/admin.key.pem");
    $certP = file_get_contents("$INT_DIR/certs/admin.crt.pem");
    $pfxPath = "$INT_DIR/certs/admin.pfx";
    save_admin_files($keyP, $certP, $pfxPath);
    echo "<h3>Admin certificate created. Download files below and keep the key safe.</h3>";
    echo "<ul>";
    echo "<li><a href='?action=download&what=admin.key'>Admin Key (PEM)</a></li>";
    echo "<li><a href='?action=download&what=admin.crt'>Admin Cert (PEM)</a></li>";
    echo "<li><a href='?action=download&what=admin.pfx'>Admin PFX (no password)</a></li>";
    echo "</ul>";
    exit;
}

// handle downloads
if ($action === 'download') {
    $what = $_GET['what'] ?? '';
    if ($what === 'root.crt') {
        $file = "$ROOT_DIR/ca.crt.pem";
        header('Content-Type: application/x-pem-file');
        header('Content-Disposition: attachment; filename="root-ca.crt.pem"');
        readfile($file);
        exit;
    } elseif ($what === 'root.delete') {
        // delete root crt for offline storage (only admin)
        if (!is_admin_authenticated()) { header('HTTP/1.1 403 Forbidden'); exit('403'); }
        unlink("$ROOT_DIR/ca.crt.pem");
        echo "Root certificate deleted from server.";
        exit;
    } elseif ($what === 'admin.key') {
        $file = "$INT_DIR/private/admin.key.pem";
        header('Content-Type: application/x-pem-file');
        header('Content-Disposition: attachment; filename="admin.key.pem"');
        readfile($file);
        exit;
    } elseif ($what === 'admin.crt') {
        $file = "$INT_DIR/certs/admin.crt.pem";
        header('Content-Type: application/x-pem-file');
        header('Content-Disposition: attachment; filename="admin.crt.pem"');
        readfile($file);
        exit;
    } elseif ($what === 'admin.pfx') {
        $file = "$INT_DIR/certs/admin.pfx";
        header('Content-Type: application/x-pkcs12');
        header('Content-Disposition: attachment; filename="admin.pfx"');
        readfile($file);
        exit;
    } elseif (strpos($what, 'cert:') === 0) {
        // download issued cert/key/pfx by name: cert:NAME:type (type optional: crt|key|pfx)
        // e.g. ?action=download&what=cert:alice.crt
        $parts = explode(':', $what, 2);
        $file = $parts[1];
        $path = "$INT_DIR/certs/$file";
        if (!file_exists($path)) { exit("file not found"); }
        $mime = 'application/octet-stream';
        header("Content-Type: $mime");
        header("Content-Disposition: attachment; filename=\"" . basename($path) . "\"");
        readfile($path);
        exit;
    }
}

// If no admin exists, show first-run create admin page
if (!get_admin_fp()) {
    echo "<h2>First run: create admin certificate</h2>";
    echo "<form method='post'><input type='hidden' name='action' value='create_admin'>CN: <input name='cn' value='admin'><button type='submit'>Create Admin Certificate</button></form>";
    exit;
}

// Admin-only functions require client cert present and valid
$admin = is_admin_authenticated();

// Basic UI
echo "<h2>Certificate Manager</h2>";
echo "<p>Admin: " . ($admin ? 'Authenticated' : 'Not authenticated (admin-only functions disabled)') . "</p>";
echo "<ul>";
echo "<li><a href='?action=list'>List issued certs</a></li>";
echo "<li><a href='?action=new'>Create new certificate (public)</a></li>";
echo "<li><a href='?action=download&what=root.crt'>Download Root Certificate (PEM)</a></li>";
if ($admin) {
    echo "<li><a href='?action=admin_panel'>Admin Panel (revoke/delete root)</a></li>";
}
echo "</ul>";

// Actions
if ($action === 'new' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $cn = escapeshellarg($_POST['cn']);
    $type = escapeshellarg($_POST['type']);
    $outname = preg_replace('/[^a-zA-Z0-9._-]/', '_', $_POST['cn']);
    $cmd = "DATA_DIR=$DATA_DIR /usr/local/bin/scripts/gen_cert.sh $cn $type $outname 2>&1";
    $out = shell_exec($cmd);
    echo "<pre>" . htmlspecialchars($out) . "</pre>";
    echo "<p><a href='?action=list'>Back to list</a></p>";
    exit;
} elseif ($action === 'new') {
    // show form
    echo "<h3>Create new certificate</h3>";
    echo "<form method='post' action='?action=new'>CN: <input name='cn' required> Type: <select name='type'><option>user</option><option>smartcard</option><option>web</option></select> <button type='submit'>Create</button></form>";
    exit;
} elseif ($action === 'list') {
    echo "<h3>Issued certificates (intermediate/certs)</h3>";
    $files = glob("$INT_DIR/certs/*");
    echo "<table border='1'><tr><th>File</th><th>Actions</th></tr>";
    foreach ($files as $f) {
        $name = basename($f);
        if (in_array($name, ['inter.crt.pem','chain.pem','admin.pfx','admin.crt.pem'])) {
            // show but limited actions
        }
        echo "<tr><td>$name</td><td>";
        echo "<a href='?action=download&what=" . urlencode("cert:$name") . "'>Download</a>";
        // if .crt and admin show revoke
        if ($admin && preg_match('/\.crt$/', $name) && $name != 'inter.crt.pem' && $name != 'admin.crt.pem') {
            // map to cert path
            $certpath = "$INT_DIR/certs/$name";
            echo " | <a href='?action=revoke&file=" . urlencode($name) . "'>Revoke</a>";
        }
        echo "</td></tr>";
    }
    echo "</table>";
    exit;
} elseif ($action === 'revoke' && $admin) {
    $name = $_GET['file'] ?? '';
    $certpath = "$INT_DIR/certs/$name";
    if (!file_exists($certpath)) { echo "No such cert"; exit; }
    $cmd = "DATA_DIR=$DATA_DIR /usr/local/bin/scripts/revoke_cert.sh " . escapeshellarg($certpath) . " 2>&1";
    $out = shell_exec($cmd);
    echo "<pre>" . htmlspecialchars($out) . "</pre>";
    echo "<p><a href='?action=list'>Back</a></p>";
    exit;
} elseif ($action === 'admin_panel' && $admin) {
    echo "<h3>Admin panel</h3>";
    echo "<p><a href='?action=download&what=root.crt'>Download root</a> | <a href='?action=download&what=root.delete' onclick='return confirm(\"Delete root from server? make sure you have backups.\")'>Delete root (offline storage)</a></p>";
    echo "<p><a href='?action=list'>Back to list</a></p>";
    exit;
}

// Default page
echo "<p>Available actions: <a href='?action=list'>list</a>, <a href='?action=new'>create cert</a></p>";
