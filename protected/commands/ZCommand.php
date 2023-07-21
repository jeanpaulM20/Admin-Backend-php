<?php

class ZCommand extends CConsoleCommand
{
    public function actionHello() {
	Yii::log('hello');
	echo "Hello 2\n";
	$review = Review::model()->findByAttributes(array('regenerate_chart' => 1));
	if ($review) {
	    $review->regenerate_chart = 0;
	    !$review->save();
	    $review->generateChart();
	    }
	}

}