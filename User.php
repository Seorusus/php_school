<?php

class User {
    public $name;
    public $age;

    /**
     * @param mixed $age
     */
    public function setAge($age) {
        if($age >18) {
            return 'New age value: ' . $age;
        } else {
            echo 'It is forbidden';
        }
        return '';
    }
}

$newUser = new User();

$newUser->name = 'John';
$newUser->age = '25';

print_r($newUser->setAge(30));