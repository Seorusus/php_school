<?php

class Employee
{
    public $name;
    public $age;
    public $salary;

    public function person($name, $age, $salary) {
        return 'Person ' . $name . 'with ' . $age . 'has salary' . $salary;
    }
}

$firstPerson = new Employee;
$secondPerson = new Employee;

echo $firstPerson->person('john', '25', '1000');
echo $secondPerson->person('eric', '26', '2000');
echo $firstPerson->salary + $secondPerson->salary;
echo $firstPerson->age + $secondPerson->age;
