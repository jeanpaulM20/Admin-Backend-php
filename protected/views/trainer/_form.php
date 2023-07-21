<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'trainer-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('trainer/create') : $this->createUrl('trainer/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'surname'); ?>
	<?php echo $form->textField($model,'surname',array('size'=>60)); ?>
	<?php echo $form->error($model,'surname'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'name'); ?>
	<?php echo $form->textField($model,'name',array('size'=>60)); ?>
	<?php echo $form->error($model,'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'position'); ?>
	<?php echo $form->textField($model,'position',array('size'=>60)); ?>
	<?php echo $form->error($model,'position'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'qualification'); ?>
	<?php echo $form->textField($model,'qualification',array('size'=>60)); ?>
	<?php echo $form->error($model,'qualification'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'e_mail'); ?>
	<?php echo $form->textField($model,'e_mail',array('size'=>60)); ?>
	<?php echo $form->error($model,'e_mail'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'phone'); ?>
	<?php echo $form->textField($model,'phone',array('size'=>60)); ?>
	<?php echo $form->error($model,'phone'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'passcode'); ?>
	<?php echo $form->passwordField($model,'passcode',array('size'=>60)); ?>
	<?php echo $form->error($model,'passcode'); ?></div>
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
		<?php echo $form->labelEx($model,'color'); ?>
		<?php $this->widget('ext.colorpalette.ActiveColorPalette', array(
			'model' => $model,
			'attribute' => 'color',
		));
		?>

		<?php echo $form->error($model,'color'); ?>
	</div>
	<div class="row">
	<?php echo $form->labelEx($model,'active'); ?>
	<?php echo $form->checkBox($model,'active'); ?>
	<?php echo $form->error($model,'active'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'published'); ?>
	<?php echo $form->checkBox($model,'published'); ?>
	<?php echo $form->error($model,'published'); ?></div>
		
	<div class="row">
<?php echo $form->labelEx($model,'locations'); ?>
<?php echo CHtml::activeDropDownList($model, 'locations', Location::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'locations'); ?>
</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('trainer/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->