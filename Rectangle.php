<?php

class Rectangle {
    public $length;
    public $height;

    public function getSquare($length, $height) {
        return $length * $height;
    }

    public function getPerimeter($length, $height) {
        return $length * 2  + $height * 2;
    }

}

$newRectangle = new Rectangle();

$square = $newRectangle->getSquare('20', '10');

echo $square;
