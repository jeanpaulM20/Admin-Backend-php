<?php

class ExercisepicturesController extends Controller
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
		
		$model=new Exercisepictures;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@e0ada6);

		if(isset($_POST['Exercisepictures']))
		{
			$model->attributes=$_POST['Exercisepictures'];
			
			
			
			
			
			
			
			if($model->save()) {
				
				
				
				
				
				
				
				$this->redirect(array('exercise/update/' . $model->exercise_id));
			}
		}

		if (!isset($_GET['exercise_id'])) {
			$this->redirect(Yii::app()->getRequest()->urlReferrer);
			return;
		} else {
			$model->exercise_id = $_GET['exercise_id'];
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
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@e0ada6);

		if(isset($_POST['Exercisepictures']))
		{
			$model->attributes=$_POST['Exercisepictures'];
			
			
			
			
			
			
			
			
			if($model->save()) {
				
				
				
				
				
				
				
				$this->redirect(array('exercise/update/' . $model->exercise_id));
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
		$model  = $this->loadModel($id);
		$model->delete();

		// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
		if(!isset($_GET['ajax']))
			$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('exercise/update/' . $model->exercise_id));
	}


	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model=Exercisepictures::model()->findByPk($id);
		if($model===null)
			throw new CHttpException(404,'The requested page does not exist.');
		return $model;
	}
	
	public function getModel()
	{
		return Exercisepictures::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if(isset($_POST['ajax']) && $_POST['ajax']==='exercise_pictures-form')
		{
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}
	
	public function actionSort()
	{
		if (isset($_POST['items']) && is_array($_POST['items'])) {
			$i = 0;
			foreach ($_POST['items'] as $item) {
				$model = $this->getModel()->findByPk($item);
				$model->sort = $i;
				$model->save();
				$i++;
			}
		}
	}

}