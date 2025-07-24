<?php

// ini_set('display_errors', '1');
// ini_set('display_startup_errors', '1');
// error_reporting(E_ALL);


define('GRAFANA_BASE_URL',
       'https://monit-grafana.cern.ch/d/RwtmMDXmz/host-metrics-simple?from=now-7d&orgId=1&to=now&var-availability_zone=All&var-bin=$__auto_interval_bin&var-environment=All&var-rp=one_week&var-hostname=');

$machines = [];
$machines["fcc-ironic-01.cern.ch"] = [
    "machine" => "OFF",
    "monitoring" => "grafana",
];
$machines["fcc-ironic-02.cern.ch"] = [
    "machine" => "OFF",
    "monitoring" => "grafana",
];
$machines["fcc-ironic-03.cern.ch"] = [
    "machine" => "OFF",
    "monitoring" => "grafana",
];
$machines["fcc-gpu-01.cern.ch"] = ["machine" => "OFF", "monitoring" => "OFF"];
$machines["fcc-gpu-02.cern.ch"] = ["machine" => "OFF", "monitoring" => "OFF"];
$machines["fcc-gpu-03.cern.ch"] = ["machine" => "OFF", "monitoring" => "OFF"];
$machines["fcc-gpu-04.cern.ch"] = [
    "machine" => "OFF",
    "monitoring" => "grafana"
];
$machines["fcc-gpu-05.cern.ch"] = [
    "machine" => "OFF",
    "monitoring" => "grafana"
];

foreach ($machines as $machine => &$status) {
    // Check if ping works
    // TODO: Using raw ping executable, ATM `SNMP Class` is not available at the
    // CERN hosting
    // $session = new SNMP(SNMP::VERSION_2c, $machine, 'boguscommunity');
    // if ($session->getError()) {
    //   $status['machine'] = 'OFF';
    // } else {
    //   $status['machine'] = 'ON';
    // }

    $ping = exec("timeout 0.2 ping -c 1 -t 64 " . $machine);
    if (empty($ping)) {
        $status["machine"] = "OFF";
    } else {
        $status["machine"] = "ON";
    }
}
unset($status);
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
            <h2>Ironic machines</h2>

            <?php print_list($machines, 'ironic'); ?>
          </div>
        </div>

        <div class="col-lg">
          <div class="text-bg-light rounded p-3 mt-3">
            <h2>GPU machines</h2>

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
  foreach ($machines as $machine => $status) {
    if (str_contains($machine, $machine_type)) {
      echo '  <li class="mb-3">' . PHP_EOL;
      echo '    <code>' . $machine . '</code>:' . PHP_EOL;
      echo '    <ul>' . PHP_EOL;
      echo '      <li>' . PHP_EOL;
      echo '        <span class="badge text-bg-'
        . (($status["machine"] == "ON") ? "success" : "danger")
        . '">'
        . $status["machine"]
        . '</span> Power state<br>'
        . PHP_EOL;
      if ($status['monitoring'] == 'grafana') {
        echo '        <span class="badge text-bg-success">'
          . '<i class="bi bi-graph-up"></i></span> '
          . '<a href="'
          . GRAFANA_BASE_URL
          . $machine
          . '" target="_link">Monitoring</a>'
          . PHP_EOL;
      } else {
        echo '        <span class="badge text-bg-danger">OFF</span> Monitoring'
          . PHP_EOL;
      }
      echo '      </li>' . PHP_EOL;
      echo '    </ul>' . PHP_EOL;
      echo '  </li>' . PHP_EOL;
    }
  }
  echo '</ul>';
}
?>
