<?php

$router = $di->getRouter();

// Define your routes here

$router->add(
  '/appstore/:params',
  [
    'controller' => 'appstore',
    'action' => 'index',
    "params"     => 1,
  ]
);

$router->add(
  '/ytube/:params',
  [
    'controller' => 'YTube',
    'action' => 'index',
    "params"     => 1,
  ]
);

$router->add(
  '/admin/:controller/:action',
  [
    'controller' => 1,
    'action' => 2,
  ]
);

$router->add(
  '/app2/:params',
  [
    'controller' => 'apps',
    'action' => 'index2',
    'params' => 1,
  ]
);

$router->add(
  '/apps/:action/:params',
  [
    'controller' => 'app',
    'action' => 'index',
    'params' => 1,
  ]
);

$router->add(
  '/app/:params',
  [
    'controller' => 'apps',
    'action' => 'index',
    "params"     => 1,
  ]
);



$router->add(
  '/link',
  [
    'controller' => 'link',
    'action' => 'index',
  ]
);

$router->handle();
