<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'client-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('client/create') : $this->createUrl('client/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'clientid'); ?>
	<?php echo $form->textField($model,'clientid',array('size'=>60)); ?>
	<?php echo $form->error($model,'clientid'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'clientpasscode'); ?>
	<?php echo $form->passwordField($model,'clientpasscode',array('size'=>60)); ?>
	<?php echo $form->error($model,'clientpasscode'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'gender'); ?>
	<?php echo $form->dropDownList($model, 'gender', $model->getGenderValues()); ?><br>
	<?php echo $form->error($model,'gender'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'surname'); ?>
	<?php echo $form->textField($model,'surname',array('size'=>60)); ?>
	<?php echo $form->error($model,'surname'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'name'); ?>
	<?php echo $form->textField($model,'name',array('size'=>60)); ?>
	<?php echo $form->error($model,'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'birthday'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'birthday',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'birthday'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'e_mail'); ?>
	<?php echo $form->textField($model,'e_mail',array('size'=>60)); ?>
	<?php echo $form->error($model,'e_mail'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'zip'); ?>
	<?php echo $form->textField($model,'zip',array('size'=>60)); ?>
	<?php echo $form->error($model,'zip'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'domicile'); ?>
	<?php echo $form->textField($model,'domicile',array('size'=>60)); ?>
	<?php echo $form->error($model,'domicile'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'phone'); ?>
	<?php echo $form->textField($model,'phone',array('size'=>60)); ?>
	<?php echo $form->error($model,'phone'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'mobile'); ?>
	<?php echo $form->textField($model,'mobile',array('size'=>60)); ?>
	<?php echo $form->error($model,'mobile'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'foto'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'foto',
)); ?>	<?php echo $form->error($model,'foto'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'min_heart_rate'); ?>
	<?php echo $form->textField($model,'min_heart_rate',array('size'=>60)); ?>
	<?php echo $form->error($model,'min_heart_rate'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'max_heart_rate'); ?>
	<?php echo $form->textField($model,'max_heart_rate',array('size'=>60)); ?>
	<?php echo $form->error($model,'max_heart_rate'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'active'); ?>
	<?php echo $form->checkBox($model,'active'); ?>
	<?php echo $form->error($model,'active'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'qrcode_static'); ?>
	<?php echo $form->checkBox($model,'qrcode_static'); ?>
	<?php echo $form->error($model,'qrcode_static'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'door_access'); ?>
	<?php echo $form->checkBox($model,'door_access'); ?>
	<?php echo $form->error($model,'door_access'); ?></div>
		
	<div class="row">
<?php echo $form->labelEx($model,'trainers'); ?>
<?php echo CHtml::activeDropDownList($model, 'trainers', Trainer::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'trainers'); ?>
</div><div class="row">
<?php echo $form->labelEx($model,'contents'); ?>
<?php echo CHtml::activeDropDownList($model, 'contents', Content::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'contents'); ?>
</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('client/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->