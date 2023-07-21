<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'performance-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('performance/create') : $this->createUrl('performance/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model, 'client_id'); ?>
		<?php echo $form->dropDownList($model, 'client_id', Client::getDropdownList(), array('id' => 'client_select')); ?>
		<?php echo $form->error($model, 'client_id'); ?>
	</div>

	<div class="row">
		<?php echo $form->labelEx($model, 'date'); ?>
		<?php
		$this->widget('zii.widgets.jui.CJuiDatePicker', array(
			'attribute'	 => 'date',
			'model'		 => $model,
			'options'	 => array(
				'showAnim'	 => 'fold',
				'dateFormat' => 'dd.mm.yy'),
		));
		?>
<?php echo $form->error($model, 'date'); ?>
	</div>
	
	
	
	<fieldset>
		<legend>Beweglichkeit</legend>
		<div class="row">
			<?php echo $form->labelEx($model, 'straight_thigh_extensors'); ?>
			<?php echo $form->textField($model, 'straight_thigh_extensors', array('size' => 60)); ?>
			<?php echo $form->error($model, 'straight_thigh_extensors'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'calfs'); ?>
			<?php echo $form->textField($model, 'calfs', array('size' => 60)); ?>
			<?php echo $form->error($model, 'calfs'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'adductors'); ?>
			<?php echo $form->textField($model, 'adductors', array('size' => 60)); ?>
			<?php echo $form->error($model, 'adductors'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'hamstrings'); ?>
			<?php echo $form->textField($model, 'hamstrings', array('size' => 60)); ?>
			<?php echo $form->error($model, 'hamstrings'); ?>
		</div>
	</fieldset>
	
	<fieldset>
		<legend>Koordination</legend>
		<div class="row">
			<?php echo $form->labelEx($model, 'points'); ?>
			<?php echo $form->textField($model, 'points', array('size' => 60)); ?>
			<?php echo $form->error($model, 'points'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'sensomotoric'); ?>
			<?php echo $form->textField($model, 'sensomotoric', array('size' => 60)); ?>
			<?php echo $form->error($model, 'sensomotoric'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'symmetry'); ?>
			<?php echo $form->textField($model, 'symmetry', array('size' => 60)); ?>
			<?php echo $form->error($model, 'symmetry'); ?>
		</div>
	</fieldset>
	
	<fieldset>
		<legend>Schnelligkeit</legend>	
		<div class="row">
			<?php echo $form->labelEx($model, 'reaction'); ?>
			<?php echo $form->textField($model, 'reaction', array('size' => 60)); ?>
			<?php echo $form->error($model, 'reaction'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'tapping'); ?>
			<?php echo $form->textField($model, 'tapping', array('size' => 60)); ?>
			<?php echo $form->error($model, 'tapping'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'counter_movement_jump'); ?>
			<?php echo $form->textField($model, 'counter_movement_jump', array('size' => 60)); ?>
			<?php echo $form->error($model, 'counter_movement_jump'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'sprint_10'); ?>
			<?php echo $form->textField($model, 'sprint_10', array('size' => 60)); ?>
			<?php echo $form->error($model, 'sprint_10'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'sprint_20'); ?>
			<?php echo $form->textField($model, 'sprint_20', array('size' => 60)); ?>
			<?php echo $form->error($model, 'sprint_20'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'sprint_30'); ?>
			<?php echo $form->textField($model, 'sprint_30', array('size' => 60)); ?>
			<?php echo $form->error($model, 'sprint_30'); ?>
		</div>
	</fieldset>
	
	<fieldset>
		<legend>Kraft</legend>
		<div class="row">
			<?php echo $form->labelEx($model, 'squat_on_wall'); ?>
			<?php echo $form->textField($model, 'squat_on_wall', array('size' => 60)); ?>
			<?php echo $form->error($model, 'squat_on_wall'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'pullups'); ?>
			<?php echo $form->textField($model, 'pullups', array('size' => 60)); ?>
			<?php echo $form->error($model, 'pullups'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'pushups'); ?>
			<?php echo $form->textField($model, 'pushups', array('size' => 60)); ?>
			<?php echo $form->error($model, 'pushups'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'trunk_bending'); ?>
			<?php echo $form->textField($model, 'trunk_bending', array('size' => 60)); ?>
			<?php echo $form->error($model, 'trunk_bending'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'forearm_support'); ?>
			<?php echo $form->textField($model, 'forearm_support', array('size' => 60)); ?>
			<?php echo $form->error($model, 'forearm_support'); ?>
		</div>
		<div class="row">
			<?php echo $form->labelEx($model, 'side_support'); ?>
			<?php echo $form->textField($model, 'side_support', array('size' => 60)); ?>
			<?php echo $form->error($model, 'side_support'); ?>
		</div>
	</fieldset>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('performance/admin') . '";'
		));
		?>
	</div>
<?php $this->endWidget(); ?>
</div><!-- form -->