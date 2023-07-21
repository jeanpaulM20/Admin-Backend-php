<?php
class ScreenstatsController extends Controller
{
	public $defaultAction = 'admin';

	public function filters()
	{
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	public function accessRules()
	{
		return array(
			array('allow',
				'users' => array('@'),
			),
			array('deny', // deny all users
				'users' => array('*'),
			),
		);
	}

	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		$model				 = new Screenstats('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Screenstats']))
			$model->attributes	 = $_GET['Screenstats'];

		$this->render('admin', array(
			'model' => $model,
		));
	}
}
