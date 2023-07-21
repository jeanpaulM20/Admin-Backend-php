<?php

class CreditsController extends Controller
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

	public function actionAdmin()
	{
Yii::log('creds admin');

		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model = new ClientCredits('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['ClientCredits'])) {
			$model->attributes	 = $_GET['ClientCredits'];
		}
		if (Yii::app()->request->getParam('client_id')) {
			$model->client_id = Yii::app()->request->getParam('client_id');
		}
		$this->render('admin', array(
			'model' => $model,
		));
	}

	public function actionAllocate() {
		
		$model = new ClientCredits('search');
		$model->client_id = Yii::app()->request->getParam('client_id');
		
		if (isset($_POST['ClientCredits'])) {
			$credits = new ClientCredits;
			$credits->client_id = Yii::app()->request->getParam('client_id');
			$model->attributes = $_POST['ClientCredits'];
			$model->training_type_id = $model->abbonement->training_type_id;
			$model->paid = $model->abbonement->lessons;
			$model->price = $model->abbonement->price;
			if ($model->abbonement->duration) {
				if ($model->startdate) {
					$model->expires = date('Y-m-d H:i:s', strtotime('+' . $model->abbonement->duration .'month', strtotime($model->startdate)));
				} else {
					$model->expires = date('Y-m-d H:i:s', strtotime('+' . $model->abbonement->duration .'month'));
					$model->startdate = null;
				}
			}
			if ($model->save()) {
				$this->redirect(array('admin', 'client_id' => Yii::app()->request->getParam('client_id')));
			}
		}
		
		$this->render('allocate', array(
			'model' => $model,
		));
	}
	
	public function actionAllocateSpecial() {
		
		$model = new ClientCredits('search');
		$model->client_id = Yii::app()->request->getParam('client_id');
		
		if (isset($_POST['ClientCredits'])) {
			$credits = new ClientCredits;
			$credits->client_id = Yii::app()->request->getParam('client_id');
			$model->attributes = $_POST['ClientCredits'];
			if ($model->save()) {
				$this->redirect(array('admin', 'client_id' => Yii::app()->request->getParam('client_id')));
			}
		}
		
		$this->render('allocate_special', array(
			'model' => $model,
		));
	}
	
	public function actionUpdate($id) {
		
		$model = $this->loadModel($id);
		
		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1a791f);

		if (isset($_POST['ClientCredits'])) {
			$model->attributes = $_POST['ClientCredits'];
			if ($model->save()) {
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
		$model = $this->loadModel($id);
		$model->delete();

		// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
		if (!isset($_GET['ajax']))
			$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('credits/admin/?client_id=' . $model->client_id));
	}

	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model = ClientCredits::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel()
	{
		return ClientCredits::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if (isset($_POST['ajax']) && $_POST['ajax'] === 'client_access_token-form') {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function actionSort()
	{
		if (isset($_POST['items']) && is_array($_POST['items'])) {
			$i = 0;
			foreach ($_POST['items'] as $item) {
				$model		 = $this->getModel()->findByPk($item);
				$model->sort = $i;
				$model->save();
				$i++;
			}
		}
	}

	public function gridActionColumn($data, $row)
	{
		$list = array('update' => 'Update','delete' => 'Delete');
		return CHtml::dropDownList('actions', '', $list, array('empty'		 => '(Action)', 'onchange'	 => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}
	
	public function actionExport() {
		$fp = fopen('php://temp', 'w');
		$headers = array(
			array(
				'name' => 'client_search',
				'value' => '$data->client ? $data->client->getModelDisplay() : ""',
			),
			array(
				'name' => 'training_type_id',
				'value' => '$data->training_type->name_en',
				'filter' => TrainingType::getDropdownList(),
			),
			array(
				'name' => 'abbonement_search',
				'value' => '$data->abbonement->title'
			),
			array(
				'name' => 'price',
				'value' => '$data->abbonement->price'
			),
			'paid',
			'attended',
			array(
				'name' => 'startdate',
				'class'=>'application.extensions.datecolumn.SYDateColumn',
			),
			array(
				'name' => 'expires',
				'class'=>'application.extensions.datecolumn.SYDateColumn',
			),
			array(
				'name' => 'sell_date',
				'class'=>'application.extensions.datecolumn.SYDateColumn',
			),
			array(
				'name' => 'soldby_search',
				'value' => '$data->sold_by ? $data->sold_by->getModelDisplay() : ""',
			),
			'professional', 
			'training_target_1', 
			'training_target_2', 
			'acquisition',
			array(
				'name' => 'client_domicile_search',
				'value' => '$data->client->domicile',
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

		$model = new ClientCredits('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['ClientCredits'])) {
			$model->attributes = $_GET['ClientCredits'];
		}
		$model->client_id = Yii::app()->request->getParam('client_id');
		$provider = $model->search();

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
	
	public function actionExportFile() {
		Yii::app()->request->sendFile('ClientCredits.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}
}