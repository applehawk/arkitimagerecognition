<?php
use Phalcon\Mvc\View;
use Phalcon\Mvc\View\Simple as SimpleView;

class ArsetController extends ControllerBase
{
    public function getAction()
    {
      $this->view->disable();

      $this->response->setHeader("Content-Type", "application/json");
      $dir = "/img/arsets/";

      $full_url = 'http://' . $_SERVER['SERVER_NAME'] . $dir;
      $list = array(); //main array

      if(is_dir("." . $dir)){
        if($dh = opendir("." . $dir)){
              while(($file = readdir($dh)) != false){
                  if($file == "." or $file == ".."){
                    //...
                  } else { //create object with two fields
                      $list3 = array(
                      'file' => $file);
                      array_push($list, $list3);
                  }
              }
          }

          $return_array = array('root' => $full_url, 'files'=> $list);
          echo json_encode($return_array);
        }
    }
}
