<?php

class Employee {
    public $name;
    public $age;
    public $salary;

    public function getName($name) {
        return 'ім`я працівника' . $name;
    }

    public function getAge($age) {
        return 'Вік працівника' . $age;
    }

    public function getSalary($salary) {
        return $salary;
    }

    public function checkAge($age) {
           return $age > 18;
    }
}

$firstPerson = new Employee();

$firstPerson->getName('Oleg');
$firstPerson->getAge('22');
$firstPerson->getSalary('1000');

$secondPerson = new Employee();

$secondPerson->getName('Serge');
$secondPerson->getAge('25');
$secondPerson->getSalary('2000');

print_r('Суму зарплат створених працівників ' . ($firstPerson->getSalary('1000') + $secondPerson->getSalary('2000')));

