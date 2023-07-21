<?php

class SettingsController extends Controller
{

	public $defaultAction = 'admin';
	public $layout = '//layouts/column1';

	/**
	 * @return array action filters
	 */
	public function filters()
	{
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	/**
	 * Specifies the access control rules.
	 * This method is used by the 'accessControl' filter.
	 * @return array access control rules
	 */
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

	/**
	 * Manages all models.
	 */
	public function actionAdmin()
	{
		if (count($_POST)) {
			foreach ($_POST as $key => $value) {
				Yii::app()->cfg->setDbItem($key, $value);
			}
		}
		
		$items = Yii::app()->cfg->toArray();
		$this->render('admin', array(
			'items' => $items,
		));
	}
	
	public function getLabel($label) {
		return ucfirst(str_replace('_', ' ', $label));
	}

}
