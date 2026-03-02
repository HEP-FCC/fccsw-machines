<?php

// ini_set('display_errors', '1');
// ini_set('display_startup_errors', '1');
// error_reporting(E_ALL);


define('GRAFANA_BASE_URL',
       'https://monit-grafana.cern.ch/d/RwtmMDXmz/host-metrics-simple?from=now-7d&orgId=1&to=now&var-availability_zone=All&var-bin=$__auto_interval_bin&var-environment=All&var-rp=one_week&var-hostname=');

$machines = [];
# Ironic Machines
$machines["fcc-ironic-01.cern.ch"] = [
    "power-state" => "OFF",
    "monitoring" => "grafana",
    # One needs to already have correct project selected, in order for this link
    # to work
    "admin" => "https://openstack.cern.ch/auth/switch/2d4dd51d-4aaf-46ea-aa47-07c865c9c6f1/?next=/project/dc9ddf39-e777-483b-b8d6-fb85db80aa79/",
];
$machines["fcc-ironic-02.cern.ch"] = [
    "power-state" => "OFF",
    "monitoring" => "grafana",
    "admin" => "https://openstack.cern.ch/auth/switch/2d4dd51d-4aaf-46ea-aa47-07c865c9c6f1/?next=/project/dac3de87-f597-4949-8bce-af5060137e37/",
];
$machines["fcc-ironic-03.cern.ch"] = [
    "power-state" => "OFF",
    "monitoring" => "grafana",
    "admin" => "https://openstack.cern.ch/auth/switch/2d4dd51d-4aaf-46ea-aa47-07c865c9c6f1/?next=/project/2c0ad3e3-04d3-4edf-acb4-d0da77e030e8/",
];

# GPU Machines
$machines["fcc-gpu-01.cern.ch"] = [
  "power-state" => "OFF",
  "monitoring" => "OFF",
  "admin" => "https://openstack.cern.ch/auth/switch/90800691-e1ae-4270-b0b2-3592289d1439/?next=/project/fcebc008-1ab1-483f-869d-4f942e2ea0bc/"
];
$machines["fcc-gpu-02.cern.ch"] = [
  "power-state" => "OFF",
  "monitoring" => "OFF",
  "admin" => "https://openstack.cern.ch/auth/switch/90800691-e1ae-4270-b0b2-3592289d1439/?next=/project/68edb32a-42ea-4ebc-a27a-ef8da5c6b602/"
];
$machines["fcc-gpu-03.cern.ch"] = [
  "power-state" => "OFF",
  "monitoring" => "OFF",
  "admin" => "https://openstack.cern.ch/auth/switch/90800691-e1ae-4270-b0b2-3592289d1439/?next=/project/cbe8043f-03a9-445e-8574-2406f8ccff71/"
];
$machines["fcc-gpu-04.cern.ch"] = [
    "power-state" => "OFF",
    "monitoring" => "grafana",
    "admin" => "https://openstack.cern.ch/auth/switch/90800691-e1ae-4270-b0b2-3592289d1439/?next=/project/253a8903-0cd3-484e-8023-e0124a5f8ead/"
];
$machines["fcc-gpu-05.cern.ch"] = [
    "power-state" => "OFF",
    "monitoring" => "grafana",
    "admin" => "https://openstack.cern.ch/auth/switch/90800691-e1ae-4270-b0b2-3592289d1439/?next=/project/b022d298-a9fc-4b53-8815-face01735caa/"
];

foreach ($machines as $machine_name => &$info) {
    // Check if ping works
    // TODO: Using raw ping executable, ATM `SNMP Class` is not available at the
    // CERN hosting
    // $session = new SNMP(SNMP::VERSION_2c, $machine_name, 'boguscommunity');
    // if ($session->getError()) {
    //   $info['power-state'] = 'OFF';
    // } else {
    //   $info['power-state'] = 'ON';
    // }

    $ping = exec("timeout 0.2 ping -c 1 -t 64 " . $machine_name);
    if (empty($ping)) {
        $info["power-state"] = "OFF";
    } else {
        $info["power-state"] = "ON";
    }
}
unset($info);
?>

<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Status of the FCC Software Machines</title>
    <link href="./bootstrap/bootstrap-5.3.3/css/bootstrap.min.css"
          rel="stylesheet">
    <link href="./bootstrap/bootstrap-icons-1.13.1/bootstrap-icons.min.css"
          rel="stylesheet">
  </head>
  <body>
    <div class="container">
      <div class="container text-center text-bg-secondary rounded p-3 mt-3">
        <h1>Status of the FCC Software Machines</h1>
      </div>

      <div class="row">
        <div class="col-lg">
          <div class="text-bg-light rounded p-3 mt-3 pl-lg-5">
            <h2>Ironic Machines</h2>

            <?php print_list($machines, 'ironic'); ?>
          </div>
        </div>

        <div class="col-lg">
          <div class="text-bg-light rounded p-3 mt-3">
            <h2>GPU Machines</h2>

            <?php print_list($machines, 'gpu'); ?>
          </div>
        </div>
      </div>
    </div>

    <script src="./bootstrap/bootstrap-5.3.3/js/bootstrap.bundle.min.js"></script>
  </body>
</html>


<?php

function print_list($machines, $machine_type) {
  echo '<ul>' . PHP_EOL;
  foreach ($machines as $machine_name => $info) {
    if (str_contains($machine_name, $machine_type)) {
      echo '  <li class="mb-3">' . PHP_EOL;
      echo '    <code>' . $machine_name . '</code>:' . PHP_EOL;
      echo '    <ul>' . PHP_EOL;
      echo '      <li>' . PHP_EOL;
      echo '        <span class="badge text-bg-'
        . (($info["power-state"] == "ON") ? "success" : "danger")
        . '">'
        . $info["power-state"]
        . '</span> Power state'
        . PHP_EOL;
      echo '      </li>' . PHP_EOL;
      echo '      <li>' . PHP_EOL;
      if ($info['monitoring'] == 'grafana') {
        echo '        <span class="badge text-bg-success">'
          . '<i class="bi bi-graph-up"></i></span> '
          . '<a href="'
          . GRAFANA_BASE_URL
          . $machine_name
          . '" target="_link">Monitoring</a>'
          . PHP_EOL;
      } else {
        echo '        <span class="badge text-bg-danger">OFF</span> Monitoring'
          . PHP_EOL;
      }
      echo '      </li>' . PHP_EOL;
      echo '      <li>' . PHP_EOL;
      echo '        <span class="badge text-bg-success">'
        . '<i class="bi bi-gear-fill"></i></span> '
        . '<a href="'
        . $info["admin"]
        . '" target="_link">Administration</a>'
        . PHP_EOL;
      echo '      </li>' . PHP_EOL;
      echo '    </ul>' . PHP_EOL;
      echo '  </li>' . PHP_EOL;
    }
  }
  echo '</ul>';
}
?>
