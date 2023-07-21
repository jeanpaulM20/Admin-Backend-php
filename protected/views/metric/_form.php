<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'metric-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('metric/create') : $this->createUrl('metric/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

		<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model,'client_id'); ?>
		<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList(), array('id' => 'client_select')); ?>
		<?php echo $form->error($model,'client_id'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model,'date'); ?>
		<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
			'attribute'=>'date',
			'model' => $model,
			'options'=>array(
				'showAnim'=>'fold',
				'dateFormat' => 'dd.mm.yy'		),
		)); ?>
		<?php echo $form->error($model,'date'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'weight'); ?>
		<?php echo $form->textField($model, 'weight', array('size'=>60)); ?>
		<?php echo $form->error($model, 'weight'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'waist_circumference'); ?>
		<?php echo $form->textField($model, 'waist_circumference', array('size'=>60)); ?>
		<?php echo $form->error($model, 'waist_circumference'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'body_fat_kg'); ?>
		<?php echo $form->textField($model, 'body_fat_kg', array('size'=>60)); ?>
		<?php echo $form->error($model, 'body_fat_kg'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'body_fat_perc'); ?>
		<?php echo $form->textField($model, 'body_fat_perc', array('size'=>60)); ?>
		<?php echo $form->error($model, 'body_fat_perc'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'bcm'); ?>
		<?php echo $form->textField($model, 'bcm', array('size'=>60)); ?>
		<?php echo $form->error($model, 'bcm'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'sys'); ?>
		<?php echo $form->textField($model, 'sys', array('size'=>60)); ?>
		<?php echo $form->error($model, 'sys'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'dia'); ?>
		<?php echo $form->textField($model, 'dia', array('size'=>60)); ?>
		<?php echo $form->error($model, 'dia'); ?>
	</div>
	
	<div class="row">
		<?php echo $form->labelEx($model, 'calm_pulse'); ?>
		<?php echo $form->textField($model, 'calm_pulse', array('size'=>60)); ?>
		<?php echo $form->error($model, 'calm_pulse'); ?>
	</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('metric/admin') . '";'
		));
		?>
	</div>
<?php $this->endWidget(); ?>
</div><!-- form -->