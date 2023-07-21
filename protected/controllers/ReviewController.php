<?php

class ReviewController extends Controller
{

	public $defaultAction	 = 'admin';
	public $layout			 = '//layouts/column1';

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
	 * Creates a new model.
	 * If creation is successful, the browser will be redirected to the 'view' page.
	 */
	public function actionCreate()
	{
		$model	 = new Review;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@f4ca49);

		if (isset($_POST['Review'])) {
			$model->attributes = $_POST['Review'];
			if ($model->save()) {
				if ($model->file) {
					$model->parseTimeSeriesFile();
				}
				$this->redirect(array('admin'));
			}
		}

		$this->render('create', array(
			'model' => $model,
		));
	}

	/**
	 * Updates a particular model.
	 * If update is successful, the browser will be redirected to the 'view' page.
	 * @param integer $id the ID of the model to be updated
	 */
	public function actionUpdate($id)
	{
		$model	 = $this->loadModel($id);
		$oldData = $model->attributes;

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@f4ca49);

		if (isset($_POST['Review'])) {
			$model->attributes = $_POST['Review'];
			if ($model->save()) {
				if ($model->file) {
					$model->parseTimeSeriesFile();
				}
				$this->redirect(array('admin'));
			}
		}

		$this->render('update', array(
			'model' => $model,
		));
	}

	/**
	 * Deletes a particular model.
	 * If deletion is successful, the browser will be redirected to the 'admin' page.
	 * @param integer $id the ID of the model to be deleted
	 */
	public function actionDelete($id)
	{
		if (Yii::app()->request->isPostRequest) {
			// we only allow deletion via POST request
			$this->loadModel($id)->delete();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if (!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400, 'Invalid request. Please do not repeat this request again.');
	}
	
	public function actionGenerateChart($id) {
		$model	 = $this->loadModel($id);
		$model->generateChart();
		$this->redirect(array('admin'));
		
	}

	/**
	 * Manages all models.
	 */
	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model				 = new Review('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Review']))
			$model->attributes	 = $_GET['Review'];

		$this->render('admin', array(
			'model' => $model,
		));
	}
	
	public function actionOffsite()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model				 = new Review('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Review']))
			$model->attributes	 = $_GET['Review'];

		$this->render('offsite', array(
			'model' => $model,
		));
	}
	
	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model = Review::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel()
	{
		return Review::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if (isset($_POST['ajax']) && $_POST['ajax'] === 'review-form') {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data, $row)
	{
		$list = array('update'		 => 'Edit', 'delete'		 => 'Delete', 'chart'			 => 'View Chart', 'generateChart'	 => 'Regenerate Chart');
		return CHtml::dropDownList('actions', '', $list, array('empty'		 => '(Action)', 'onchange'	 => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}

	public function actionExport()
	{
		$fp		 = fopen('php://temp', 'w');
		$headers = array(
			'id',
			'file',
			'duration',
			'kcal',
			'heart_rate',
			array(
				'name'	 => 'exerciseset_search',
				'value'	 => '$data->exerciseset->name ',
			),
			array(
				'name'	 => 'training_search',
				'value'	 => '$data->training->date  . " " . $data->training->starttime  . " " . $data->training->getEndTime() ',
			),
		);

		$row = array();
		foreach ($headers as $header) {
			if (is_array($header)) {
				$row[] = $this->getModel()->getAttributeLabel($header['name']);
			} else {
				$row[] = $this->getModel()->getAttributeLabel($header);
			}
		}
		fputcsv($fp, $row);

		$model = new Review('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Review'])) {
			$model->attributes	 = $_GET['Review'];
		}
		$provider			 = $model->search();

		foreach ($provider->getData() as $model) {
			$row = array();
			foreach ($headers as $header) {
				if (is_array($header)) {
					if (isset($header['value'])) {
						$row[] = $this->evaluateExpression($header['value'], array('data' => $model));
					} else {
						$row[] = CHtml::value($model, $header['name']);
					}
				} else {
					$row[] = CHtml::value($model, $header);
				}
			}
			fputcsv($fp, $row);
		}
		rewind($fp);
		Yii::app()->user->setState('export', stream_get_contents($fp));
		fclose($fp);
	}

	public function actionExportFile()
	{
		Yii::app()->request->sendFile('Review.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}

}
