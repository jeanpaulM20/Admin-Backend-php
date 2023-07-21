<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'file-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('file/create') : $this->createUrl('file/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'name'); ?>
	<?php echo $form->textField($model,'name',array('size'=>60)); ?>
	<?php echo $form->error($model,'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'date'); ?>
	<?php $this->widget('application.extensions.timepicker.EJuiDateTimePicker',array(
		'model'=>$model,
		'attribute'=>'date',
		'options'=>array(
			'dateFormat' => 'yy-mm-dd',
			'timeFormat' => 'hh:mm',
		),
	)); ?>
	<?php echo $form->error($model,'date'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'file'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'file',
)); ?>	<?php echo $form->error($model,'file'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList()); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('file/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->