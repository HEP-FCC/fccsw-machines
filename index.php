<?php

// ini_set('display_errors', '1');
// ini_set('display_startup_errors', '1');
// error_reporting(E_ALL);

$machines = array();
$machines['fcc-ironic-01.cern.ch'] = array('machine' => 'OFF',
                                           'monitoring' => 'OFF');
$machines['fcc-ironic-02.cern.ch'] = array('machine' => 'OFF',
                                           'monitoring' => 'OFF');
$machines['fcc-ironic-03.cern.ch'] = array('machine' => 'OFF',
                                           'monitoring' => 'OFF');
$machines['fcc-gpu-01.cern.ch'] = array('machine' => 'OFF',
                                        'monitoring' => 'OFF');
$machines['fcc-gpu-02.cern.ch'] = array('machine' => 'OFF',
                                        'monitoring' => 'OFF');
$machines['fcc-gpu-03.cern.ch'] = array('machine' => 'OFF',
                                        'monitoring' => 'OFF');
$machines['fcc-gpu-04v2.cern.ch'] = array('machine' => 'OFF',
                                          'monitoring' => 'OFF');
$machines['fcc-gpu-05.cern.ch'] = array('machine' => 'OFF',
                                        'monitoring' => 'OFF');

foreach ($machines as $machine => &$status) {
  // Check if ping works
  // Using raw ping executable,SNMP Class is not available at CERN hosting
  $ping = exec("ping -c 1 -t 64 " . $machine);
  if (empty($ping)) {
    $status['machine'] = 'OFF';
  } else {
    $status['machine'] = 'ON';
  }
  // $session = new SNMP(SNMP::VERSION_2c, $machine, 'boguscommunity');
  // if ($session->getError()) {
  //   $status['machine'] = 'OFF';
  // } else {
  //   $status['machine'] = 'ON';
  // }

  // Check if Monitorix is up
  $connection = @fsockopen($machine, 8080);
  if (is_resource($connection)) {
    $status['monitoring'] = 'ON';
    fclose($connection);
  } else {
    $status['monitoring'] = 'OFF';
  }
}
unset($status);
?>

<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Status of FCC Software Machines</title>
    <link href="./bootstrap/bootstrap-5.3.3/css/bootstrap.min.css"
          rel="stylesheet">
  </head>
  <body>
    <div class="container">
      <h1>Status of FCC Software Machines</h1>

      <h2>Ironic machines</h2>

      <ul>
        <?php foreach ($machines as $machine => $status): ?>
        <?php if (str_contains($machine, 'ironic')): ?>
        <li class="mb-3">
          <code><?= $machine ?></code>:
          <ul>
            <li>
              <span class="badge text-bg-<?php echo ($status['machine'] == 'ON') ? 'success' : 'danger'; ?>"><?= $status['machine'] ?></span>
              Power state
            </li>
            <li>
              <span class="badge text-bg-<?php echo ($status['monitoring'] == 'ON') ? 'success' : 'danger'; ?>"><?= $status['monitoring'] ?></span>
              <a href="http://<?= $machine ?>:8080/monitorix">Monitoring</a>
            </li>
          </ul>
        </li>
        <?php endif ?>
        <?php endforeach ?>
      </ul>

      <h2>GPU machines</h2>

      <ul>
        <?php foreach ($machines as $machine => $status): ?>
        <?php if (!(str_contains($machine, 'ironic'))): ?>
        <li class="mb-3">
          <code><?= $machine ?></code>:
          <ul>
            <li>
              <span class="badge text-bg-<?php echo ($status['machine'] == 'ON') ? 'success' : 'danger'; ?>"><?= $status['machine'] ?></span>
              Power state
            </li>
            <li>
              <span class="badge text-bg-<?php echo ($status['monitoring'] == 'ON') ? 'success' : 'danger'; ?>"><?= $status['monitoring'] ?></span>
              <a href="http://<?= $machine ?>:8080/monitorix">Monitoring</a>
            </li>
          </ul>
        </li>
        <?php endif ?>
        <?php endforeach ?>
      </ul>
    </div>

    <script src="./bootstrap/bootstrap-5.3.3/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
