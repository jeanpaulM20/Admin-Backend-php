<?php
$this->breadcrumbs=array(
	'Door log'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Door logs</h1>

<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'door-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('door-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		array(
			'name' => 'date',
			'class'=>'application.extensions.datecolumn.SYDateColumn',
		),
		'action',
		'comment',
		array(
			'name' => 'client_search',
			'value'=>'$data->client ? $data->client->getModelDisplay() : ""',
		),
		array(
			'name' => 'trainer_search',
			'value'=>'$data->trainer ? $data->trainer->getModelDisplay() : ""',
		),
	),
)); ?>
