<?php

class User {
    public $name;
    public $age;

    /**
     * @param mixed $age
     */
    public function setAge($age)
    {
        return $age;
    }
}

$newUser = new User();

$newUser->name = 'John';
$newUser->age = '25';

print_r('нове значення віку: ' . $newUser->setAge(30));