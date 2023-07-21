<?php

class PreferenceController extends Controller
{
	public $defaultAction = 'admin';

	public $layout='//layouts/column1';

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
				'users'=>array('@'),
			),
			array('deny',  // deny all users
				'users'=>array('*'),
			),
		);
	}

	/**
	 * Creates a new model.
	 * If creation is successful, the browser will be redirected to the 'view' page.
	 */
	public function actionCreate()
	{
		$model=new Preference;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1479ef9);

		if(isset($_POST['Preference']))
		{
			$model->attributes=$_POST['Preference'];
			
			
			
			
			
			if($model->save()) {
				
				
				
				
				
				$this->redirect(array('admin'));
			}
		}

		$this->render('create',array(
			'model'=>$model,
		));
	}

	/**
	 * Updates a particular model.
	 * If update is successful, the browser will be redirected to the 'view' page.
	 * @param integer $id the ID of the model to be updated
	 */
	public function actionUpdate($id)
	{
		$model=$this->loadModel($id);
		$oldData = $model->attributes;

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1479ef9);

		if(isset($_POST['Preference']))
		{
			$model->attributes=$_POST['Preference'];
			
			
			
			
			
			
			if($model->save()) {
				
				
				
				
				
				$this->redirect(array('admin'));
			}
		}

		$this->render('update',array(
			'model'=>$model,
		));
	}

	/**
	 * Deletes a particular model.
	 * If deletion is successful, the browser will be redirected to the 'admin' page.
	 * @param integer $id the ID of the model to be deleted
	 */
	public function actionDelete($id)
	{
		if(Yii::app()->request->isPostRequest)
		{
			// we only allow deletion via POST request
			$this->loadModel($id)->delete();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if(!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400,'Invalid request. Please do not repeat this request again.');
	}


	/**
	 * Manages all models.
	 */
	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize',(int)$_GET['pageSize']);
			unset($_GET['pageSize']);
		}
		
		if(Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}
		
		$model=new Preference('search');
		$model->unsetAttributes();  // clear any default values
		if(isset($_GET['Preference']))
			$model->attributes=$_GET['Preference'];

		$this->render('admin',array(
			'model'=>$model,
		));
	}

	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model=Preference::model()->findByPk($id);
		if($model===null)
			throw new CHttpException(404,'The requested page does not exist.');
		return $model;
	}
	
	public function getModel()
	{
		return Preference::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if(isset($_POST['ajax']) && $_POST['ajax']==='preference-form')
		{
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data,$row) {
		$list = array('update' => 'Edit', 'delete' => 'Delete');
		return CHtml::dropDownList('actions', '',
			$list,
			array('empty' => '(Action)', 'onchange'=> 'js:processAction($(this).val(), ' . $data->id . ');')
        );
	}
	
	
	
	
	

	public function actionExport() {
		$fp = fopen('php://temp', 'w');
		$headers = array(
							'id',
							array(
	'name' => 'preferred_trainer_search',
	'value'=>'$data->preferred_trainer->surname  . " " . $data->preferred_trainer->name ',
),
							array(
	'name' => 'preferred_language_search',
	'value'=>'$data->preferred_language->language ',
),
							array(
	'name' => 'preferred_location_search',
	'value'=>'$data->preferred_location->name ',
),
							array(
	'name' => 'client_search',
	'value'=>'$data->client->clientid  . " " . $data->client->surname  . " " . $data->client->name ',
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
		fputcsv($fp,$row);
		
		$model=new Preference('search');
		$model->unsetAttributes();  // clear any default values
		if(isset($_GET['Preference'])) {
			$model->attributes=$_GET['Preference'];
		}
		$provider = $model->search();
		
		foreach($provider->getData() as $model) {
			$row = array();
            foreach($headers as $header) {
				if (is_array($header)) {
					if (isset($header['value'])) {
						$row[] = $this->evaluateExpression($header['value'], array('data' => $model));
					} else {
						$row[] = CHtml::value($model,$header['name']);
					}
				} else {
					$row[] = CHtml::value($model,$header);
				}
            }
            fputcsv($fp,$row);
		}
		rewind($fp);
		Yii::app()->user->setState('export',stream_get_contents($fp));
		fclose($fp);
		
	}
	
	public function actionExportFile()
	{
		Yii::app()->request->sendFile('Preference.csv',Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}
}
